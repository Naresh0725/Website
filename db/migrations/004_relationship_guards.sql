BEGIN;
CREATE FUNCTION exam.guard_result_membership() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
DECLARE result_attempt uuid; member_attempt uuid;
BEGIN
 SELECT attempt_id INTO result_attempt FROM attempt_results WHERE id=NEW.result_id;
 IF TG_TABLE_NAME='answer_evaluations' THEN SELECT attempt_id INTO member_attempt FROM attempt_questions WHERE id=NEW.attempt_question_id;
 ELSE SELECT attempt_id INTO member_attempt FROM attempt_sections WHERE id=NEW.attempt_section_id; END IF;
 IF result_attempt IS DISTINCT FROM member_attempt THEN RAISE EXCEPTION 'RESULT_ATTEMPT_MISMATCH'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER evaluation_membership BEFORE INSERT OR UPDATE ON exam.answer_evaluations FOR EACH ROW EXECUTE FUNCTION exam.guard_result_membership();
CREATE TRIGGER section_result_membership BEFORE INSERT OR UPDATE ON exam.result_section_summaries FOR EACH ROW EXECUTE FUNCTION exam.guard_result_membership();
CREATE FUNCTION exam.guard_result_revision() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
BEGIN
 IF NEW.supersedes_result_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM attempt_results WHERE id=NEW.supersedes_result_id AND attempt_id=NEW.attempt_id AND grading_version<NEW.grading_version) THEN RAISE EXCEPTION 'INVALID_RESULT_REVISION'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER result_revision BEFORE INSERT ON exam.attempt_results FOR EACH ROW EXECUTE FUNCTION exam.guard_result_revision();
CREATE TRIGGER immutable_results BEFORE UPDATE OR DELETE ON exam.attempt_results FOR EACH ROW EXECUTE FUNCTION exam.no_mutation();
CREATE TRIGGER immutable_evaluations BEFORE UPDATE OR DELETE ON exam.answer_evaluations FOR EACH ROW EXECUTE FUNCTION exam.no_mutation();
CREATE FUNCTION exam.guard_group() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM question_group_members m JOIN question_versions v ON v.id=m.question_version_id WHERE m.group_id=OLD.id AND v.review_status='published') THEN RAISE EXCEPTION 'PUBLISHED_GROUP_IMMUTABLE'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
CREATE TRIGGER group_immutable BEFORE UPDATE OR DELETE ON exam.question_groups FOR EACH ROW EXECUTE FUNCTION exam.guard_group();
-- Prices/coverage/duration are new plan versions, never mutable purchased terms.
CREATE TRIGGER immutable_plan_versions BEFORE UPDATE OR DELETE ON exam.subscription_plan_versions FOR EACH ROW EXECUTE FUNCTION exam.no_mutation();
CREATE FUNCTION exam.guard_plan_coverage() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
DECLARE p uuid;
BEGIN
 p:=CASE WHEN TG_OP='DELETE' THEN OLD.plan_version_id ELSE NEW.plan_version_id END;
 IF EXISTS(SELECT 1 FROM payment_orders WHERE plan_version_id=p) OR (TG_OP='UPDATE' AND EXISTS(SELECT 1 FROM payment_orders WHERE plan_version_id=OLD.plan_version_id)) THEN RAISE EXCEPTION 'PURCHASED_COVERAGE_IMMUTABLE'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
CREATE TRIGGER plan_coverage_guard BEFORE INSERT OR UPDATE OR DELETE ON exam.plan_exam_access FOR EACH ROW EXECUTE FUNCTION exam.guard_plan_coverage();
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA exam FROM PUBLIC;
COMMIT;
