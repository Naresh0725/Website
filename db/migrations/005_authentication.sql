BEGIN;
CREATE ROLE exam_auth NOLOGIN;
GRANT USAGE ON SCHEMA exam TO exam_auth;
CREATE TABLE exam.auth_sessions (
 token_hash text PRIMARY KEY CHECK(token_hash ~ '^[a-f0-9]{64}$'),
 user_id uuid NOT NULL REFERENCES exam.users,
 encrypted_tokens text NOT NULL,
 scope text NOT NULL CHECK(scope IN ('account','recovery')),
 csrf_hash text NOT NULL CHECK(csrf_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL,
 idle_expires_at timestamptz NOT NULL,
 CHECK(expires_at>created_at AND expires_at<=created_at+interval '24 hours')
);
CREATE INDEX ON exam.auth_sessions(user_id);
CREATE TABLE exam.auth_flows (
 token_hash text PRIMARY KEY CHECK(token_hash ~ '^[a-f0-9]{64}$'),
 encrypted_verifier text NOT NULL,
 expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '10 minutes'
);
CREATE TABLE exam.auth_rate_limits (bucket text PRIMARY KEY, count integer NOT NULL, reset_at timestamptz NOT NULL);
CREATE TABLE exam.auth_security_events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES exam.users, event_type text NOT NULL, occurred_at timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE TRIGGER immutable_auth_events BEFORE UPDATE OR DELETE ON exam.auth_security_events FOR EACH ROW EXECUTE FUNCTION exam.no_mutation();
ALTER TABLE exam.auth_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam.auth_flows ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam.auth_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam.auth_security_events ENABLE ROW LEVEL SECURITY;
INSERT INTO exam.roles(code) VALUES ('student'),('account_admin');
INSERT INTO exam.permissions(code) VALUES ('profile.read_self'),('profile.write_self'),('roles.manage');
INSERT INTO exam.role_permissions SELECT r.id,p.id FROM exam.roles r CROSS JOIN exam.permissions p WHERE (r.code='student' AND p.code IN ('profile.read_self','profile.write_self')) OR (r.code='account_admin' AND p.code='roles.manage');
INSERT INTO exam.user_roles(user_id,role_id) SELECT u.id,r.id FROM exam.users u CROSS JOIN exam.roles r WHERE r.code='student' ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION exam.provision_user(p_user uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
BEGIN
 INSERT INTO users(id) VALUES(p_user) ON CONFLICT DO NOTHING;
 INSERT INTO user_profiles(user_id) VALUES(p_user) ON CONFLICT DO NOTHING;
 INSERT INTO user_free_allowances(user_id) VALUES(p_user) ON CONFLICT DO NOTHING;
 INSERT INTO user_roles(user_id,role_id) SELECT p_user,id FROM roles WHERE code='student' ON CONFLICT DO NOTHING;
END $$;
CREATE FUNCTION exam.account_profile(p_user uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM users WHERE id=p_user AND status='active') THEN RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE'; END IF;
 SELECT jsonb_build_object('id',p.user_id,'display_name',p.display_name,'preferred_language',p.preferred_language,'timezone',p.timezone,
 'roles',COALESCE((SELECT jsonb_agg(r.code ORDER BY r.code) FROM user_roles ur JOIN roles r ON r.id=ur.role_id WHERE ur.user_id=p_user),'[]'),
 'permissions',COALESCE((SELECT jsonb_agg(x.code ORDER BY x.code) FROM (SELECT DISTINCT perm.code FROM user_roles ur JOIN role_permissions rp ON rp.role_id=ur.role_id JOIN permissions perm ON perm.id=rp.permission_id WHERE ur.user_id=p_user) x),'[]')) INTO result FROM user_profiles p WHERE p.user_id=p_user;
 RETURN result;
END $$;
CREATE FUNCTION exam.update_account_profile(p_user uuid,p_name text,p_language text,p_timezone text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
BEGIN
 PERFORM account_profile(p_user);
 IF p_name IS NULL OR length(trim(p_name)) NOT BETWEEN 1 AND 100 OR p_language IS NULL OR p_language NOT IN ('en','hi','te','ta','kn','ml','mr','bn','gu','pa','or','ur') OR p_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_timezone) THEN RAISE EXCEPTION 'INVALID_PROFILE'; END IF;
 UPDATE user_profiles SET display_name=trim(p_name),preferred_language=p_language,timezone=p_timezone WHERE user_id=p_user;
 RETURN account_profile(p_user);
END $$;
CREATE FUNCTION exam.change_account_role(p_actor uuid,p_target uuid,p_role text,p_grant boolean,p_reason text,p_mfa boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE rid uuid;
BEGIN
 IF p_mfa IS DISTINCT FROM true THEN RAISE EXCEPTION 'MFA_REQUIRED'; END IF;
 IF p_actor=p_target OR p_reason IS NULL OR length(trim(p_reason))<5 THEN RAISE EXCEPTION 'INVALID_ROLE_CHANGE'; END IF;
 IF NOT EXISTS(SELECT 1 FROM users u JOIN user_roles ur ON ur.user_id=u.id JOIN role_permissions rp ON rp.role_id=ur.role_id JOIN permissions p ON p.id=rp.permission_id WHERE u.id=p_actor AND u.status='active' AND p.code='roles.manage') THEN RAISE EXCEPTION 'ROLE_CHANGE_FORBIDDEN'; END IF;
 SELECT id INTO rid FROM roles WHERE code=p_role;
 IF rid IS NULL OR p_role='student' OR NOT EXISTS(SELECT 1 FROM users WHERE id=p_target AND status='active') THEN RAISE EXCEPTION 'INVALID_ROLE_CHANGE'; END IF;
 IF p_grant THEN INSERT INTO user_roles(user_id,role_id,granted_by) VALUES(p_target,rid,p_actor) ON CONFLICT DO NOTHING;
 ELSE DELETE FROM user_roles WHERE user_id=p_target AND role_id=rid; END IF;
 INSERT INTO admin_audit_logs(actor_id,action,entity_type,entity_id,after_value,reason,request_id) VALUES(p_actor,'account.role_change','user',p_target,jsonb_build_object('role',p_role,'granted',p_grant),p_reason,gen_random_uuid());
END $$;
CREATE FUNCTION exam.create_auth_session(p_hash text,p_user uuid,p_tokens text,p_scope text,p_csrf text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
BEGIN
 PERFORM account_profile(p_user);
 INSERT INTO auth_sessions(token_hash,user_id,encrypted_tokens,scope,csrf_hash,expires_at,idle_expires_at) VALUES(p_hash,p_user,p_tokens,p_scope,p_csrf,clock_timestamp()+CASE WHEN p_scope='recovery' THEN interval '10 minutes' ELSE interval '24 hours' END,clock_timestamp()+CASE WHEN p_scope='recovery' THEN interval '10 minutes' ELSE interval '30 minutes' END);
 INSERT INTO auth_security_events(user_id,event_type) VALUES(p_user,CASE WHEN p_scope='recovery' THEN 'recovery_session_created' ELSE 'login' END);
END $$;
-- Call inside a transaction. This row lock serializes refresh-token rotation across processes.
CREATE FUNCTION exam.lock_auth_session(p_hash text) RETURNS SETOF exam.auth_sessions LANGUAGE sql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
 SELECT s.* FROM auth_sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=p_hash AND u.status='active' AND s.expires_at>clock_timestamp() AND s.idle_expires_at>clock_timestamp() FOR UPDATE OF s;
$$;
CREATE FUNCTION exam.touch_auth_session(p_hash text,p_tokens text) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
 UPDATE auth_sessions SET encrypted_tokens=p_tokens,idle_expires_at=least(expires_at,clock_timestamp()+interval '30 minutes') WHERE token_hash=p_hash;
$$;
CREATE FUNCTION exam.delete_auth_session(p_hash text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE u uuid;
BEGIN
 DELETE FROM auth_sessions WHERE token_hash=p_hash RETURNING user_id INTO u;
 IF u IS NOT NULL THEN INSERT INTO auth_security_events(user_id,event_type) VALUES(u,'logout'); END IF;
END $$;
CREATE FUNCTION exam.revoke_account_sessions(p_user uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
BEGIN
 DELETE FROM auth_sessions WHERE user_id=p_user;
 INSERT INTO auth_security_events(user_id,event_type) VALUES(p_user,'all_sessions_revoked');
END $$;
CREATE FUNCTION exam.create_auth_flow(p_hash text,p_verifier text) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$ INSERT INTO auth_flows(token_hash,encrypted_verifier) VALUES(p_hash,p_verifier); $$;
CREATE FUNCTION exam.consume_auth_flow(p_hash text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE f auth_flows;
BEGIN
 DELETE FROM auth_flows WHERE token_hash=p_hash RETURNING * INTO f;
 IF f.expires_at<=clock_timestamp() THEN RETURN NULL; END IF;
 RETURN f.encrypted_verifier;
END $$;
CREATE FUNCTION exam.auth_rate_limit(p_bucket text,p_limit integer,p_seconds integer) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE n integer;
BEGIN
 IF p_limit<1 OR p_seconds<1 THEN RAISE EXCEPTION 'INVALID_RATE_POLICY'; END IF;
 INSERT INTO auth_rate_limits(bucket,count,reset_at) VALUES(p_bucket,1,clock_timestamp()+make_interval(secs=>p_seconds))
 ON CONFLICT(bucket) DO UPDATE SET count=CASE WHEN auth_rate_limits.reset_at<=clock_timestamp() THEN 1 ELSE auth_rate_limits.count+1 END,reset_at=CASE WHEN auth_rate_limits.reset_at<=clock_timestamp() THEN clock_timestamp()+make_interval(secs=>p_seconds) ELSE auth_rate_limits.reset_at END RETURNING count INTO n;
 RETURN n<=p_limit;
END $$;
GRANT EXECUTE ON FUNCTION exam.provision_user(uuid),exam.account_profile(uuid),exam.update_account_profile(uuid,text,text,text),exam.change_account_role(uuid,uuid,text,boolean,text,boolean),exam.create_auth_session(text,uuid,text,text,text),exam.lock_auth_session(text),exam.touch_auth_session(text,text),exam.delete_auth_session(text),exam.revoke_account_sessions(uuid),exam.create_auth_flow(text,text),exam.consume_auth_flow(text),exam.auth_rate_limit(text,integer,integer) TO exam_auth;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA exam FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA exam FROM PUBLIC;
COMMIT;
