-- Optional deployment adapter, run only in a NEW Supabase project after migrations.
-- Browser auth identifiers are owned by Supabase; entitlement rows are never recreated on login.
BEGIN;
ALTER TABLE exam.users ADD CONSTRAINT managed_auth_identity FOREIGN KEY(id) REFERENCES auth.users(id) ON DELETE RESTRICT;
CREATE FUNCTION exam.on_auth_identity() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=exam,pg_catalog AS $$
BEGIN
 PERFORM exam.provision_user(NEW.id);
 RETURN NEW;
END $$;
REVOKE EXECUTE ON FUNCTION exam.on_auth_identity() FROM PUBLIC;
CREATE TRIGGER government_exam_identity AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION exam.on_auth_identity();
COMMIT;
