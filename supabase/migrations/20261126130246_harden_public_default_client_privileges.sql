-- Remove anonymous direct-write and browser-role DDL grants from all public
-- tables/views. No anon write policies exist in public, all base tables have
-- RLS enabled, and all public views are security_invoker.
-- Preserve SELECT for anon and CRUD for authenticated; RLS remains authoritative.
DO $$
DECLARE
  relation_row record;
BEGIN
  FOR relation_row IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
  LOOP
    EXECUTE format(
      'REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE %I.%I FROM anon',
      'public',
      relation_row.relname
    );
    EXECUTE format(
      'REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE %I.%I FROM authenticated',
      'public',
      relation_row.relname
    );
  END LOOP;
END
$$;

-- Future objects created by the postgres migration owner must follow the
-- same least-privilege policy. supabase_admin-owned defaults are managed by
-- that role and require a separate owner-authorized Dashboard operation.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLES FROM authenticated;
