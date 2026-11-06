-- Cache auth.uid() once per statement in HR row-level security predicates.
-- Preserve each policy's existing roles, commands, and authorization conditions.
DO $$
DECLARE
  p record;
  v_using text;
  v_check text;
  v_stmt text;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (coalesce(qual, '') LIKE '%= auth.uid()%'
        OR coalesce(with_check, '') LIKE '%= auth.uid()%')
  LOOP
    v_using := CASE
      WHEN p.qual IS NOT NULL
      THEN ' USING (' || replace(p.qual, '= auth.uid()', '= (select auth.uid())') || ')'
      ELSE ''
    END;
    v_check := CASE
      WHEN p.with_check IS NOT NULL
      THEN ' WITH CHECK (' || replace(p.with_check, '= auth.uid()', '= (select auth.uid())') || ')'
      ELSE ''
    END;
    v_stmt := format(
      'ALTER POLICY %I ON %I.%I%s%s',
      p.policyname, p.schemaname, p.tablename, v_using, v_check
    );
    EXECUTE v_stmt;
  END LOOP;
END
$$;
