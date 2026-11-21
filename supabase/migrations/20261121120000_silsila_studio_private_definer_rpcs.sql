begin;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter function public.erp_studio_has_action_permission(uuid, text) set schema private;
alter function public.erp_studio_save_draft(uuid, uuid, text, text, text, integer, jsonb, jsonb, integer, text) set schema private;
alter function public.erp_studio_approve_design(uuid, uuid, integer) set schema private;
alter function public.erp_studio_publish_design(uuid, uuid, integer) set schema private;
alter function public.erp_studio_restore_version(uuid, uuid, integer, integer) set schema private;

revoke all on function private.erp_studio_has_action_permission(uuid, text) from public, anon;
revoke all on function private.erp_studio_save_draft(uuid, uuid, text, text, text, integer, jsonb, jsonb, integer, text) from public, anon;
revoke all on function private.erp_studio_approve_design(uuid, uuid, integer) from public, anon;
revoke all on function private.erp_studio_publish_design(uuid, uuid, integer) from public, anon;
revoke all on function private.erp_studio_restore_version(uuid, uuid, integer, integer) from public, anon;
grant execute on function private.erp_studio_has_action_permission(uuid, text) to authenticated;
grant execute on function private.erp_studio_save_draft(uuid, uuid, text, text, text, integer, jsonb, jsonb, integer, text) to authenticated;
grant execute on function private.erp_studio_approve_design(uuid, uuid, integer) to authenticated;
grant execute on function private.erp_studio_publish_design(uuid, uuid, integer) to authenticated;
grant execute on function private.erp_studio_restore_version(uuid, uuid, integer, integer) to authenticated;

create or replace function public.erp_studio_has_action_permission(
  p_company_id uuid,
  p_action text
) returns boolean
language sql
stable
security invoker
set search_path = pg_catalog
as $wrapper$
  select private.erp_studio_has_action_permission(p_company_id, p_action);
$wrapper$;

create or replace function public.erp_studio_save_draft(
  p_company_id uuid,
  p_design_id uuid,
  p_design_key text,
  p_name text,
  p_design_kind text,
  p_schema_version integer,
  p_design_json jsonb,
  p_binding_json jsonb,
  p_expected_revision integer default null,
  p_change_note text default null
) returns uuid
language sql
security invoker
set search_path = pg_catalog
as $wrapper$
  select private.erp_studio_save_draft(
    p_company_id, p_design_id, p_design_key, p_name, p_design_kind,
    p_schema_version, p_design_json, p_binding_json, p_expected_revision, p_change_note
  );
$wrapper$;

create or replace function public.erp_studio_approve_design(
  p_company_id uuid,
  p_design_id uuid,
  p_expected_revision integer
) returns boolean
language sql
security invoker
set search_path = pg_catalog
as $wrapper$
  select private.erp_studio_approve_design(p_company_id, p_design_id, p_expected_revision);
$wrapper$;

create or replace function public.erp_studio_publish_design(
  p_company_id uuid,
  p_design_id uuid,
  p_tested_revision integer
) returns boolean
language sql
security invoker
set search_path = pg_catalog
as $wrapper$
  select private.erp_studio_publish_design(p_company_id, p_design_id, p_tested_revision);
$wrapper$;

create or replace function public.erp_studio_restore_version(
  p_company_id uuid,
  p_design_id uuid,
  p_target_revision integer,
  p_expected_revision integer
) returns integer
language sql
security invoker
set search_path = pg_catalog
as $wrapper$
  select private.erp_studio_restore_version(p_company_id, p_design_id, p_target_revision, p_expected_revision);
$wrapper$;

revoke all on function public.erp_studio_has_action_permission(uuid, text) from public, anon;
revoke all on function public.erp_studio_save_draft(uuid, uuid, text, text, text, integer, jsonb, jsonb, integer, text) from public, anon;
revoke all on function public.erp_studio_approve_design(uuid, uuid, integer) from public, anon;
revoke all on function public.erp_studio_publish_design(uuid, uuid, integer) from public, anon;
revoke all on function public.erp_studio_restore_version(uuid, uuid, integer, integer) from public, anon;
grant execute on function public.erp_studio_has_action_permission(uuid, text) to authenticated;
grant execute on function public.erp_studio_save_draft(uuid, uuid, text, text, text, integer, jsonb, jsonb, integer, text) to authenticated;
grant execute on function public.erp_studio_approve_design(uuid, uuid, integer) to authenticated;
grant execute on function public.erp_studio_publish_design(uuid, uuid, integer) to authenticated;
grant execute on function public.erp_studio_restore_version(uuid, uuid, integer, integer) to authenticated;

commit;