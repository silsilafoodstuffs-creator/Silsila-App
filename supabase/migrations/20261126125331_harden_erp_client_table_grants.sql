-- Keep ERP browser clients on least-privilege grants.
-- RLS policies continue to control row-level CRUD for authenticated users.
-- Anonymous clients retain SELECT only; no ERP anon write policies exist.
-- TRUNCATE/REFERENCES/TRIGGER are table-level privileges and are not protected by RLS.
DO $$
DECLARE
  relation_row record;
BEGIN
  FOR relation_row IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname LIKE 'erp\_%' ESCAPE '\'
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
