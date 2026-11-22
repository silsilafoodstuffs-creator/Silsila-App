---
name: database-security
description: Security review for Silsila Supabase Auth, PostgreSQL grants, RLS, RPCs, Storage, secrets, and tenant isolation.
---

# Database Security for Silsila

## Threat model
- Treat every client, browser, mobile device, request parameter, uploaded file, and user-editable profile field as untrusted.
- Enforce company/activity/branch/warehouse boundaries on the server, not only in Flutter UI filters.
- Verify actual roles and ownership relationships from trusted database-side records.

## RLS and privileges
- Enable and verify RLS for tables exposed to the Supabase Data API.
- Review SELECT, INSERT, UPDATE, and DELETE policies separately; UPDATE must enforce both row visibility and new-row validity.
- Use least-privilege grants and explicit policy roles.
- Do not rely on hidden UI controls, client-supplied company IDs, or user-editable `user_metadata` for authorization.
- Review views, materialized views, functions, triggers, and RPC execute grants for RLS bypasses.
- Avoid `SECURITY DEFINER`; if unavoidable, restrict schema exposure and EXECUTE grants, validate caller authorization, and pin a safe search_path.
- Never expose service-role keys, database passwords, or secret tokens in app code, logs, or committed files.

## Verification
- Test allowed and denied access for multiple companies, branches, roles, and unauthenticated users.
- Include cross-tenant negative tests; a successful admin query alone is insufficient.
- Review Storage bucket visibility and object-level policies.
- Do not weaken policies to silence an error. Diagnose the missing intended permission instead.
- Never execute destructive SQL or change production grants/policies without explicit authorization.
