-- Silsila RLS performance hardening.
-- Safe, semantics-preserving optimization: cache auth.uid() once per statement in
-- row-level security predicates instead of re-evaluating it for every row.
-- The policy recreation preserves each policy's name, target, role list,
-- permissive/restrictive mode, command, USING expression and WITH CHECK expression.
-- Also removes redundant owner policies where an identical ALL policy remains.
-- This migration does not modify application data.

BEGIN;

DO $rls_optimize$
DECLARE
  pol record;
  role_list text;
  using_expr text;
  check_expr text;
  stmt text;
BEGIN
  FOR pol IN
    SELECT *
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (
        (qual IS NOT NULL
          AND qual ~* 'auth[.]uid[(][)]'
          AND qual !~* 'select[[:space:]]+auth[.]uid[(][)]')
        OR
        (with_check IS NOT NULL
          AND with_check ~* 'auth[.]uid[(][)]'
          AND with_check !~* 'select[[:space:]]+auth[.]uid[(][)]')
      )
  LOOP
    using_expr := pol.qual;
    check_expr := pol.with_check;

    IF using_expr IS NOT NULL
       AND using_expr ~* 'auth[.]uid[(][)]'
       AND using_expr !~* 'select[[:space:]]+auth[.]uid[(][)]' THEN
      using_expr := regexp_replace(
        using_expr, 'auth[.]uid[(][)]', '(select auth.uid())', 'gi'
      );
    END IF;

    IF check_expr IS NOT NULL
       AND check_expr ~* 'auth[.]uid[(][)]'
       AND check_expr !~* 'select[[:space:]]+auth[.]uid[(][)]' THEN
      check_expr := regexp_replace(
        check_expr, 'auth[.]uid[(][)]', '(select auth.uid())', 'gi'
      );
    END IF;

    SELECT string_agg(
      CASE WHEN role_name::text = 'public'
           THEN 'PUBLIC'
           ELSE quote_ident(role_name::text)
      END,
      ', ' ORDER BY role_name::text
    )
    INTO role_list
    FROM unnest(pol.roles) AS roles(role_name);

    EXECUTE format(
      'DROP POLICY %I ON %I.%I',
      pol.policyname, pol.schemaname, pol.tablename
    );

    stmt := format(
      'CREATE POLICY %I ON %I.%I AS %s FOR %s TO %s',
      pol.policyname, pol.schemaname, pol.tablename,
      lower(pol.permissive), pol.cmd, role_list
    );

    IF using_expr IS NOT NULL THEN
      stmt := stmt || format(' USING (%s)', using_expr);
    END IF;
    IF check_expr IS NOT NULL THEN
      stmt := stmt || format(' WITH CHECK (%s)', check_expr);
    END IF;

    EXECUTE stmt;
  END LOOP;
END
$rls_optimize$;

-- Keep the single equivalent owner policy for each table. These removals are
-- redundant-policy cleanup only; the remaining ALL policy has the same predicate.
DROP POLICY IF EXISTS addresses_delete_own ON public.addresses;
DROP POLICY IF EXISTS addresses_insert_own ON public.addresses;
DROP POLICY IF EXISTS addresses_select_own ON public.addresses;
DROP POLICY IF EXISTS addresses_update_own ON public.addresses;

DROP POLICY IF EXISTS favorites_delete_own ON public.favorites;
DROP POLICY IF EXISTS favorites_insert_own ON public.favorites;
DROP POLICY IF EXISTS favorites_select_own ON public.favorites;

DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;

-- These duplicate profile policies are replaced by the equivalent policies
-- "Users can view own profile" and "Users can update own profile".
DROP POLICY IF EXISTS profiles_select_authenticated ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;

COMMIT;

-- Post-apply checks:
-- 1) Every public table should have RLS enabled:
-- SELECT relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
-- WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity;
-- Expected result: no rows.
--
-- 2) Count remaining direct auth.uid() policy expressions that are not cached:
-- SELECT count(*) FROM pg_policies WHERE schemaname='public' AND
-- ((coalesce(qual,'') ~* 'auth[.]uid[(][)]' AND coalesce(qual,'') !~* 'select[[:space:]]+auth[.]uid[(][)]')
-- OR (coalesce(with_check,'') ~* 'auth[.]uid[(][)]' AND coalesce(with_check,'') !~* 'select[[:space:]]+auth[.]uid[(][)]'));
-- Expected result: 0.
