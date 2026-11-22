---
name: supabase-postgres-best-practices
description: Secure, reliable Supabase and PostgreSQL practices for Silsila. Use for database schema, SQL, migrations, RLS, Auth, Storage, RPCs, and data-access code.
---

# Supabase and PostgreSQL Best Practices for Silsila

## Mandatory safety principles

- Read current Supabase documentation before implementing a feature that depends on changing Supabase behavior or APIs.
- Inspect the existing schema, migrations, policies, triggers, functions, and data-access code before proposing a change.
- Never reset, truncate, delete, or seed production data as part of routine development.
- Never expose Supabase `service_role` or secret keys in Flutter or any client-side code. Use only public/publishable client credentials in the app.
- Do not weaken RLS to make a failing query work.
- Do not run destructive SQL or apply a migration without explicit user authorization for the specific change.
- Skills and advice do not authorize a schema or data mutation.

## PostgreSQL design

- Use appropriate primary keys, foreign keys, unique constraints, check constraints, and indexes.
- Model relationships explicitly; preserve referential integrity when consolidating or re-coding records.
- Use transactions for multi-step data changes that must succeed or fail together.
- Make migrations reversible where practical and document any irreversible operation.
- Avoid duplicate indexes and redundant constraints.
- Use `EXPLAIN (ANALYZE, BUFFERS)` only when it is safe to execute the query and representative data is available; be mindful that ANALYZE runs the query.
- Prefer set-based SQL over row-by-row loops for bulk operations, with careful validation and transaction boundaries.
- Avoid N+1 queries and select only needed columns.

## Supabase RLS and authorization

- Enable RLS on tables exposed through the Data API.
- Policies must reflect the actual Silsila tenant, branch, activity, role, and ownership model—not a generic `auth.uid() = user_id` assumption.
- `TO authenticated` alone is not authorization; combine it with a correct row-level predicate.
- For UPDATE policies, ensure both `USING` and `WITH CHECK` enforce the intended row ownership/tenant boundary.
- Do not use user-editable `user_metadata` as an authorization source. Use trusted app metadata or server-side authorization data.
- Views can bypass RLS by default; use `security_invoker = true` where supported, or otherwise restrict exposure and grants.
- Avoid `SECURITY DEFINER` unless necessary. If required, use a non-exposed schema, validate caller identity, restrict EXECUTE grants, and review the function's search path.
- Never use `auth.role()` as the authorization test; use policy role clauses such as `TO authenticated` and explicit predicates.
- UPDATE requires a matching SELECT policy for rows to be visible to the operation.

## Supabase Storage and API

- Review bucket visibility and object policies before changing upload behavior.
- Storage upsert generally requires the appropriate INSERT, SELECT, and UPDATE privileges/policies.
- Do not assume a table is exposed through the Data API merely because it exists; verify grants and Data API settings.
- Pin dependency versions and commit the corresponding lockfile when a package change is justified.

## Required verification for database changes

1. Explain the intended schema/data impact before execution.
2. Review foreign keys, triggers, policies, views, and dependent application queries.
3. Validate record counts and relationship integrity before and after any authorized data migration.
4. Test with representative least-privilege roles, not only an administrator.
5. Run available Supabase advisors and relevant SQL/application tests.
6. Report the exact migration, queries, checks, and any remaining risk.

Reference: https://github.com/supabase/agent-skills/tree/main/skills/supabase-postgres-best-practices
