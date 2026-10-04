BEGIN;
CREATE FUNCTION exam.guard_question_version() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
DECLARE correct jsonb;
BEGIN
 IF TG_OP<>'INSERT' AND OLD.review_status='published' THEN RAISE EXCEPTION 'PUBLISHED_QUESTION_IMMUTABLE'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 IF NEW.review_status='published' THEN
   IF NOT EXISTS(SELECT 1 FROM question_translations WHERE question_version_id=NEW.id AND review_status='approved') THEN RAISE EXCEPTION 'APPROVED_TRANSLATION_REQUIRED'; END IF;
   SELECT answer_specification INTO correct FROM question_answer_keys WHERE question_version_id=NEW.id;
   IF NOT FOUND THEN RAISE EXCEPTION 'ANSWER_KEY_REQUIRED'; END IF;
   IF NEW.question_type='single_choice' AND ((SELECT count(*) FROM question_options WHERE question_version_id=NEW.id)<2 OR NOT EXISTS(SELECT 1 FROM question_options WHERE question_version_id=NEW.id AND option_key=correct->>'option_key')) THEN RAISE EXCEPTION 'INVALID_OPTIONS_OR_KEY'; END IF;
   NEW.published_at:=clock_timestamp();
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_question_version BEFORE INSERT OR UPDATE OR DELETE ON exam.question_versions FOR EACH ROW EXECUTE FUNCTION exam.guard_question_version();
CREATE FUNCTION exam.guard_question_child() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
DECLARE old_id uuid; new_id uuid;
BEGIN
 IF TG_TABLE_NAME='question_option_translations' THEN
  IF TG_OP<>'INSERT' THEN SELECT question_version_id INTO old_id FROM question_options WHERE id=OLD.option_id; END IF;
  IF TG_OP<>'DELETE' THEN SELECT question_version_id INTO new_id FROM question_options WHERE id=NEW.option_id; END IF;
 ELSE
  IF TG_OP<>'INSERT' THEN old_id:=OLD.question_version_id; END IF;
  IF TG_OP<>'DELETE' THEN new_id:=NEW.question_version_id; END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM question_versions WHERE id IN(old_id,new_id) AND review_status='published') THEN RAISE EXCEPTION 'PUBLISHED_QUESTION_IMMUTABLE'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
DO $$ DECLARE n text; BEGIN FOREACH n IN ARRAY ARRAY['question_translations','question_options','question_option_translations','question_answer_keys','question_topic_mappings','question_assets','question_group_members'] LOOP EXECUTE format('CREATE TRIGGER published_question_child BEFORE INSERT OR UPDATE OR DELETE ON exam.%I FOR EACH ROW EXECUTE FUNCTION exam.guard_question_child()',n); END LOOP; END $$;
CREATE FUNCTION exam.guard_pyq() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
BEGIN
 IF NEW.evidence_status='verified_pyq' AND NOT EXISTS(SELECT 1 FROM question_versions v JOIN questions q ON q.id=v.question_id CROSS JOIN exam_papers p WHERE v.id=NEW.question_version_id AND q.origin_type='historical' AND p.id=NEW.paper_id AND p.key_status='final_verified' AND p.key_source_id IS NOT NULL) THEN RAISE EXCEPTION 'VERIFIED_PYQ_EVIDENCE_REQUIRED'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER verified_pyq_guard BEFORE INSERT OR UPDATE ON exam.question_paper_occurrences FOR EACH ROW EXECUTE FUNCTION exam.guard_pyq();
CREATE FUNCTION exam.guard_test_version() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
BEGIN
 IF TG_OP<>'INSERT' AND OLD.published_at IS NOT NULL THEN RAISE EXCEPTION 'PUBLISHED_TEST_IMMUTABLE'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 IF NEW.published_at IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM syllabus_versions sv JOIN mock_tests mt ON mt.exam_stage_id=sv.exam_stage_id WHERE sv.id=NEW.syllabus_version_id AND mt.id=NEW.mock_test_id) THEN RAISE EXCEPTION 'SYLLABUS_STAGE_MISMATCH'; END IF;
  IF NEW.assembly_mode='fixed' THEN
   IF NOT EXISTS(SELECT 1 FROM test_sections WHERE test_version_id=NEW.id) OR EXISTS(SELECT 1 FROM test_sections s WHERE s.test_version_id=NEW.id AND s.question_count<>(SELECT count(*) FROM test_questions tq WHERE tq.test_section_id=s.id)) THEN RAISE EXCEPTION 'INVALID_QUESTION_INVENTORY'; END IF;
   IF EXISTS(SELECT 1 FROM test_sections s JOIN test_questions tq ON tq.test_section_id=s.id JOIN question_versions q ON q.id=tq.question_version_id WHERE s.test_version_id=NEW.id AND q.review_status<>'published') THEN RAISE EXCEPTION 'UNPUBLISHED_QUESTION'; END IF;
   IF EXISTS(SELECT tq.question_version_id FROM test_sections s JOIN test_questions tq ON tq.test_section_id=s.id WHERE s.test_version_id=NEW.id GROUP BY tq.question_version_id HAVING count(*)>1) THEN RAISE EXCEPTION 'DUPLICATE_QUESTION'; END IF;
   IF EXISTS(SELECT 1 FROM mock_tests WHERE id=NEW.mock_test_id AND test_mode='pyq') AND EXISTS(SELECT 1 FROM test_sections s JOIN test_questions tq ON tq.test_section_id=s.id WHERE s.test_version_id=NEW.id AND NOT EXISTS(SELECT 1 FROM question_paper_occurrences o JOIN exam_papers p ON p.id=o.paper_id JOIN mock_tests mt ON mt.id=NEW.mock_test_id WHERE o.question_version_id=tq.question_version_id AND o.evidence_status='verified_pyq' AND p.exam_stage_id=mt.exam_stage_id)) THEN RAISE EXCEPTION 'STRICT_PYQ_REQUIRED'; END IF;
  END IF;
 END IF; RETURN NEW;
END $$;
CREATE TRIGGER test_version_guard BEFORE INSERT OR UPDATE OR DELETE ON exam.test_versions FOR EACH ROW EXECUTE FUNCTION exam.guard_test_version();
CREATE FUNCTION exam.guard_test_child() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
DECLARE old_id uuid; new_id uuid;
BEGIN
 IF TG_TABLE_NAME='test_sections' THEN
  IF TG_OP<>'INSERT' THEN old_id:=OLD.test_version_id; END IF;
  IF TG_OP<>'DELETE' THEN new_id:=NEW.test_version_id; END IF;
 ELSE
  IF TG_OP<>'INSERT' THEN SELECT test_version_id INTO old_id FROM test_sections WHERE id=OLD.test_section_id; END IF;
  IF TG_OP<>'DELETE' THEN SELECT test_version_id INTO new_id FROM test_sections WHERE id=NEW.test_section_id; END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM test_versions WHERE id IN(old_id,new_id) AND published_at IS NOT NULL) THEN RAISE EXCEPTION 'PUBLISHED_TEST_IMMUTABLE'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
CREATE TRIGGER test_section_guard BEFORE INSERT OR UPDATE OR DELETE ON exam.test_sections FOR EACH ROW EXECUTE FUNCTION exam.guard_test_child();
CREATE TRIGGER test_question_guard BEFORE INSERT OR UPDATE OR DELETE ON exam.test_questions FOR EACH ROW EXECUTE FUNCTION exam.guard_test_child();
CREATE TRIGGER test_blueprint_guard BEFORE INSERT OR UPDATE OR DELETE ON exam.test_blueprint_rules FOR EACH ROW EXECUTE FUNCTION exam.guard_test_child();
CREATE FUNCTION exam.guard_topic_cycle() RETURNS trigger LANGUAGE plpgsql SET search_path=exam,pg_catalog AS $$
BEGIN
 IF EXISTS(WITH RECURSIVE ancestors AS (SELECT id,parent_topic_id FROM topics WHERE id=NEW.parent_topic_id UNION SELECT t.id,t.parent_topic_id FROM topics t JOIN ancestors a ON t.id=a.parent_topic_id) SELECT 1 FROM ancestors WHERE id=NEW.id) THEN RAISE EXCEPTION 'TOPIC_CYCLE'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER topic_cycle_guard BEFORE INSERT OR UPDATE ON exam.topics FOR EACH ROW EXECUTE FUNCTION exam.guard_topic_cycle();
-- Keep all newly introduced functions private.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA exam FROM PUBLIC;
COMMIT;
