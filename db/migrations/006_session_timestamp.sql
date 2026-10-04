BEGIN;
-- Use one wall-clock snapshot for all session deadlines. Separate clock_timestamp()
-- calls can differ by microseconds and violate the strict maximum-duration check.
CREATE OR REPLACE FUNCTION exam.create_auth_session(p_hash text,p_user uuid,p_tokens text,p_scope text,p_csrf text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
DECLARE created timestamptz:=clock_timestamp();
BEGIN
 PERFORM account_profile(p_user);
 INSERT INTO auth_sessions(token_hash,user_id,encrypted_tokens,scope,csrf_hash,created_at,expires_at,idle_expires_at)
 VALUES(p_hash,p_user,p_tokens,p_scope,p_csrf,created,
 created+CASE WHEN p_scope='recovery' THEN interval '10 minutes' ELSE interval '24 hours' END,
 created+CASE WHEN p_scope='recovery' THEN interval '10 minutes' ELSE interval '30 minutes' END);
 INSERT INTO auth_security_events(user_id,event_type) VALUES(p_user,CASE WHEN p_scope='recovery' THEN 'recovery_session_created' ELSE 'login' END);
END $$;
REVOKE EXECUTE ON FUNCTION exam.create_auth_session(text,uuid,text,text,text) FROM PUBLIC;
COMMIT;
