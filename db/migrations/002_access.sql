BEGIN;
-- Identity is supplied only by a trusted authenticated backend, never a browser RPC.
CREATE FUNCTION exam.provision_user(p_user uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
BEGIN
 INSERT INTO users(id) VALUES(p_user) ON CONFLICT DO NOTHING;
 INSERT INTO user_profiles(user_id) VALUES(p_user) ON CONFLICT DO NOTHING;
 INSERT INTO user_free_allowances(user_id) VALUES(p_user) ON CONFLICT DO NOTHING;
END $$;

CREATE FUNCTION exam.start_attempt(p_user uuid,p_test uuid,p_request uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
#variable_conflict use_variable
DECLARE a user_attempts; tv test_versions; u users; used integer; period_id uuid; exam_id_for_test uuid; attempt_id uuid:=gen_random_uuid(); ev uuid; t timestamptz; n integer;
BEGIN
 IF p_request IS NULL THEN RAISE EXCEPTION 'REQUEST_KEY_REQUIRED'; END IF;
 SELECT * INTO u FROM users WHERE id=p_user;
 IF NOT FOUND OR u.status<>'active' THEN RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE'; END IF;
 -- All entitlement mutations use this same row and lock order.
 SELECT used_count INTO used FROM user_free_allowances WHERE user_id=p_user FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_PROVISIONED'; END IF;
 SELECT * INTO a FROM user_attempts WHERE user_id=p_user AND start_request_key=p_request;
 IF FOUND THEN
   IF a.test_version_id<>p_test THEN RAISE EXCEPTION 'IDEMPOTENCY_CONFLICT'; END IF;
   RETURN a.id;
 END IF;
 SELECT * INTO tv FROM test_versions WHERE id=p_test AND published_at IS NOT NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'TEST_NOT_PUBLISHED'; END IF;
 -- Dynamic assembly is intentionally fail-closed until its implementation phase.
 IF tv.assembly_mode<>'fixed' THEN RAISE EXCEPTION 'BLUEPRINT_ASSEMBLY_NOT_IMPLEMENTED'; END IF;
 SELECT es.exam_id INTO exam_id_for_test FROM mock_tests mt JOIN exam_stages es ON es.id=mt.exam_stage_id WHERE mt.id=tv.mock_test_id AND mt.status='published';
 IF NOT FOUND THEN RAISE EXCEPTION 'TEST_NOT_AVAILABLE'; END IF;
 SELECT count(*) INTO n FROM test_sections WHERE test_version_id=p_test;
 IF n=0 OR EXISTS(SELECT 1 FROM test_sections s WHERE s.test_version_id=p_test AND s.question_count<>(SELECT count(*) FROM test_questions q WHERE q.test_section_id=s.id)) THEN RAISE EXCEPTION 'INVALID_QUESTION_INVENTORY'; END IF;
 IF EXISTS(SELECT 1 FROM test_sections s JOIN test_questions tq ON tq.test_section_id=s.id JOIN question_versions q ON q.id=tq.question_version_id LEFT JOIN question_answer_keys k ON k.question_version_id=q.id WHERE s.test_version_id=p_test AND (q.review_status<>'published' OR k.question_version_id IS NULL)) THEN RAISE EXCEPTION 'INVALID_QUESTION_INVENTORY'; END IF;
 t:=clock_timestamp();
 -- The approved exact rule: first two charged starts are FREE, even if prepaid.
 IF used>=2 THEN
   SELECT sp.id INTO period_id FROM subscription_periods sp
   JOIN user_subscriptions us ON us.id=sp.subscription_id
   JOIN subscription_plan_versions pv ON pv.id=us.plan_version_id
   WHERE us.user_id=p_user AND us.status='active' AND sp.status='active'
    AND sp.starts_at<=t AND t<sp.ends_at
    AND (pv.all_exams OR EXISTS(SELECT 1 FROM plan_exam_access x WHERE x.plan_version_id=pv.id AND x.exam_id=exam_id_for_test))
   ORDER BY sp.ends_at DESC LIMIT 1;
   IF period_id IS NULL THEN RAISE EXCEPTION 'SUBSCRIPTION_REQUIRED'; END IF;
 END IF;
 INSERT INTO user_attempts(id,user_id,test_version_id,start_request_key,started_at,deadline_at,rules_snapshot)
 VALUES(attempt_id,p_user,p_test,p_request,t,t+tv.duration_seconds*interval '1 second',tv.rules);
 INSERT INTO attempt_sections(attempt_id,test_version_id,test_section_id) SELECT attempt_id,p_test,id FROM test_sections WHERE test_version_id=p_test;
 INSERT INTO attempt_questions(attempt_id,attempt_section_id,question_version_id,position,option_order,scoring_snapshot,topic_snapshot)
 SELECT attempt_id,asec.id,tq.question_version_id,row_number() OVER(ORDER BY s.position,tq.position),
  COALESCE((SELECT jsonb_agg(o.id ORDER BY o.display_order) FROM question_options o WHERE o.question_version_id=tq.question_version_id),'[]'),
  COALESCE(tq.scoring_override,s.scoring_rule),
  COALESCE((SELECT jsonb_agg(m.topic_id ORDER BY m.topic_id) FROM question_topic_mappings m WHERE m.question_version_id=tq.question_version_id),'[]')
 FROM test_sections s JOIN test_questions tq ON tq.test_section_id=s.id JOIN attempt_sections asec ON asec.test_section_id=s.id AND asec.attempt_id=attempt_id
 WHERE s.test_version_id=p_test;
 IF used<2 THEN
   UPDATE user_free_allowances SET used_count=used_count+1 WHERE user_id=p_user;
   INSERT INTO free_attempt_events(user_id,attempt_id,event_type,delta_used) VALUES(p_user,attempt_id,'consume',1) RETURNING id INTO ev;
   INSERT INTO attempt_authorizations VALUES(attempt_id,'free',NULL,ev,'{"free_limit":2,"consume_at":"start","policy":"approved-2026-10-04"}');
 ELSE
   INSERT INTO attempt_authorizations VALUES(attempt_id,'subscription',period_id,NULL,'{"duration_hours":720,"policy":"approved-2026-10-04"}');
 END IF;
 INSERT INTO attempt_events(attempt_id,event_type,request_key) VALUES(attempt_id,'started',p_request);
 RETURN attempt_id;
END $$;

CREATE FUNCTION exam.get_attempt(p_user uuid,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE a user_attempts;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM users WHERE id=p_user AND status='active') THEN RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE'; END IF;
 SELECT * INTO a FROM user_attempts WHERE id=p_attempt AND user_id=p_user;
 IF NOT FOUND THEN RAISE EXCEPTION 'ATTEMPT_NOT_FOUND'; END IF;
 RETURN jsonb_build_object('id',a.id,'test_version_id',a.test_version_id,'status',a.status,'started_at',a.started_at,'deadline_at',a.deadline_at,'deadline_passed',clock_timestamp()>=a.deadline_at);
END $$;

CREATE FUNCTION exam.access_status(p_user uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE n integer;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM users WHERE id=p_user AND status='active') THEN RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE'; END IF;
 SELECT used_count INTO n FROM user_free_allowances WHERE user_id=p_user;
 IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_PROVISIONED'; END IF;
 RETURN jsonb_build_object('free_used',n,'free_remaining',2-n,'subscription_required_for_next_start',n=2);
END $$;

CREATE FUNCTION exam.restore_attempt(p_actor uuid,p_attempt uuid,p_reason text,p_incident text,p_request uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE owner_id uuid; a user_attempts; consumed free_attempt_events; restored uuid; used integer;
BEGIN
 IF p_request IS NULL OR p_reason IS NULL OR length(trim(p_reason))<5 OR p_incident IS NULL OR length(trim(p_incident))<3 THEN RAISE EXCEPTION 'INCIDENT_AND_REASON_REQUIRED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM users u JOIN user_roles ur ON ur.user_id=u.id JOIN role_permissions rp ON rp.role_id=ur.role_id JOIN permissions p ON p.id=rp.permission_id WHERE u.id=p_actor AND u.status='active' AND p.code='attempt.restore') THEN RAISE EXCEPTION 'RESTORE_FORBIDDEN'; END IF;
 SELECT user_id INTO owner_id FROM user_attempts WHERE id=p_attempt;
 IF NOT FOUND THEN RAISE EXCEPTION 'ATTEMPT_NOT_FOUND'; END IF;
 SELECT used_count INTO used FROM user_free_allowances WHERE user_id=owner_id FOR UPDATE;
 SELECT * INTO a FROM user_attempts WHERE id=p_attempt FOR UPDATE;
 SELECT id INTO restored FROM free_attempt_events WHERE attempt_id=p_attempt AND event_type='restore';
 IF FOUND THEN RETURN restored; END IF;
 SELECT * INTO consumed FROM free_attempt_events WHERE attempt_id=p_attempt AND event_type='consume';
 IF NOT FOUND THEN RAISE EXCEPTION 'NOT_A_FREE_ATTEMPT'; END IF;
 -- Paid access is unlimited during its interval; it cannot create extra free credits.
 UPDATE user_attempts SET status='voided' WHERE id=p_attempt;
 UPDATE user_free_allowances SET used_count=used_count-1 WHERE user_id=owner_id;
 INSERT INTO free_attempt_events(user_id,attempt_id,event_type,delta_used,reverses_event_id,reason,actor_id) VALUES(owner_id,p_attempt,'restore',-1,consumed.id,p_reason,p_actor) RETURNING id INTO restored;
 INSERT INTO admin_audit_logs(actor_id,action,entity_type,entity_id,before_value,after_value,reason,request_id)
 VALUES(p_actor,'attempt.restore','attempt',p_attempt,jsonb_build_object('status',a.status,'used',used),jsonb_build_object('status','voided','used',used-1,'incident',p_incident),p_reason,p_request);
 INSERT INTO attempt_events(attempt_id,event_type,request_key,metadata) VALUES(p_attempt,'restored',p_request,jsonb_build_object('incident',p_incident));
 INSERT INTO outbox_events(event_type,aggregate_id,payload) VALUES('attempt.voided',p_attempt,jsonb_build_object('rebuild_analytics',true));
 RETURN restored;
END $$;

-- Callable ONLY by the trusted billing role after cryptographic + provider API verification.
CREATE FUNCTION exam.activate_verified_payment(p_order uuid,p_payment text,p_amount bigint,p_currency text,p_evidence_hash text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE o payment_orders; pv subscription_plan_versions; owner_id uuid; existing_payment payments; paid_id uuid; sub_id uuid; period_id uuid; begin_at timestamptz;
BEGIN
 IF p_payment IS NULL OR length(trim(p_payment))=0 OR p_evidence_hash IS NULL OR p_evidence_hash !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'VERIFICATION_EVIDENCE_REQUIRED'; END IF;
 SELECT user_id INTO owner_id FROM payment_orders WHERE id=p_order;
 IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
 PERFORM 1 FROM user_free_allowances WHERE user_id=owner_id FOR UPDATE;
 SELECT * INTO o FROM payment_orders WHERE id=p_order FOR UPDATE;
 IF o.amount_minor IS DISTINCT FROM p_amount OR o.currency IS DISTINCT FROM p_currency THEN RAISE EXCEPTION 'PAYMENT_MISMATCH'; END IF;
 SELECT * INTO existing_payment FROM payments WHERE provider_payment_id=p_payment;
 IF FOUND THEN
   IF existing_payment.order_id<>p_order OR existing_payment.status<>'captured' THEN RAISE EXCEPTION 'PAYMENT_CONFLICT'; END IF;
   SELECT id INTO period_id FROM subscription_periods WHERE payment_id=existing_payment.id;
   RETURN period_id;
 END IF;
 IF o.status<>'created' THEN RAISE EXCEPTION 'ORDER_ALREADY_FULFILLED_OR_CANCELLED'; END IF;
 SELECT * INTO pv FROM subscription_plan_versions WHERE id=o.plan_version_id;
 IF pv.price_minor<>p_amount OR pv.currency<>p_currency THEN RAISE EXCEPTION 'PLAN_PRICE_MISMATCH'; END IF;
 INSERT INTO payments(order_id,provider_payment_id,amount_minor,currency,status,verified_at,captured_at) VALUES(p_order,p_payment,p_amount,p_currency,'captured',clock_timestamp(),clock_timestamp()) RETURNING id INTO paid_id;
 INSERT INTO payment_verification_events(payment_id,method,outcome,provider_status,evidence_hash) VALUES(paid_id,'signature_and_provider_api','verified','captured',p_evidence_hash);
 INSERT INTO user_subscriptions(user_id,plan_version_id) VALUES(o.user_id,o.plan_version_id) ON CONFLICT(user_id,plan_version_id) DO UPDATE SET status='active' RETURNING id INTO sub_id;
 SELECT greatest(clock_timestamp(),COALESCE(max(ends_at),clock_timestamp())) INTO begin_at FROM subscription_periods WHERE subscription_id=sub_id AND status='active';
 INSERT INTO subscription_periods(subscription_id,starts_at,ends_at,payment_id) VALUES(sub_id,begin_at,begin_at+interval '720 hours',paid_id) RETURNING id INTO period_id;
 UPDATE payment_orders SET status='paid' WHERE id=p_order;
 INSERT INTO outbox_events(event_type,aggregate_id,payload) VALUES('subscription.activated',sub_id,jsonb_build_object('period_id',period_id));
 RETURN period_id;
END $$;

CREATE FUNCTION exam.no_mutation() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'APPEND_ONLY'; END $$;
CREATE TRIGGER immutable_free_events BEFORE UPDATE OR DELETE ON exam.free_attempt_events FOR EACH ROW EXECUTE FUNCTION exam.no_mutation();
CREATE TRIGGER immutable_audit BEFORE UPDATE OR DELETE ON exam.admin_audit_logs FOR EACH ROW EXECUTE FUNCTION exam.no_mutation();
CREATE TRIGGER immutable_payment_evidence BEFORE UPDATE OR DELETE ON exam.payment_verification_events FOR EACH ROW EXECUTE FUNCTION exam.no_mutation();

-- Browser roles receive no grants at all. Backend roles have EXECUTE only.
DO $$ DECLARE n text; BEGIN
 FOREACH n IN ARRAY ARRAY['exam_runtime','exam_identity','exam_billing','exam_support'] LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=n) THEN EXECUTE format('CREATE ROLE %I NOLOGIN',n); END IF;
  IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=n AND (rolsuper OR rolcanlogin OR rolbypassrls)) THEN RAISE EXCEPTION 'UNSAFE_EXISTING_ROLE: %',n; END IF;
 END LOOP;
END $$;
REVOKE ALL ON ALL TABLES IN SCHEMA exam FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA exam FROM PUBLIC;
GRANT USAGE ON SCHEMA exam TO exam_runtime,exam_identity,exam_billing,exam_support;
GRANT EXECUTE ON FUNCTION exam.provision_user(uuid) TO exam_identity;
GRANT EXECUTE ON FUNCTION exam.start_attempt(uuid,uuid,uuid),exam.get_attempt(uuid,uuid),exam.access_status(uuid) TO exam_runtime;
GRANT EXECUTE ON FUNCTION exam.restore_attempt(uuid,uuid,text,text,uuid) TO exam_support;
GRANT EXECUTE ON FUNCTION exam.activate_verified_payment(uuid,text,bigint,text,text) TO exam_billing;
ALTER DEFAULT PRIVILEGES IN SCHEMA exam REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA exam REVOKE ALL ON TABLES FROM PUBLIC;
-- Defense in depth: no direct browser policy exists, including for answer keys.
DO $$ DECLARE t record; BEGIN FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='exam' LOOP EXECUTE format('ALTER TABLE exam.%I ENABLE ROW LEVEL SECURITY',t.tablename); END LOOP; END $$;
COMMIT;
