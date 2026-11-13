-- Silsila Studio metadata and immutable revision history.
-- Review and apply manually; this file is not executed by the Flutter client.
begin;

create table if not exists public.erp_studio_designs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  design_key text not null,
  name text not null check (length(trim(name)) between 1 and 160),
  design_kind text not null default 'screen'
    check (design_kind in ('screen','report','icon','tree','table','grid','form','component')),
  schema_version integer not null default 1 check (schema_version > 0),
  status text not null default 'draft'
    check (status in ('draft','review','approved','published','archived')),
  design_json jsonb not null default '{"schemaVersion":1,"nodes":[]}'::jsonb,
  binding_json jsonb not null default '{"mode":"unbound","sources":[]}'::jsonb,
  revision integer not null default 1 check (revision > 0),
  published_revision integer,
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, design_key),
  check (published_revision is null or published_revision <= revision)
);

create index if not exists erp_studio_designs_company_status_idx
  on public.erp_studio_designs(company_id, status, updated_at desc);

create table if not exists public.erp_studio_design_versions (
  id uuid primary key default gen_random_uuid(),
  design_id uuid not null references public.erp_studio_designs(id) on delete cascade,
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  revision integer not null check (revision > 0),
  design_json jsonb not null,
  binding_json jsonb not null,
  change_note text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (design_id, revision)
);

create index if not exists erp_studio_versions_company_design_idx
  on public.erp_studio_design_versions(company_id, design_id, revision desc);

create table if not exists public.erp_studio_audit_log (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  design_id uuid references public.erp_studio_designs(id) on delete set null,
  action_key text not null check (length(trim(action_key)) between 1 and 80),
  details jsonb not null default '{}'::jsonb,
  actor_user_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists erp_studio_audit_company_created_idx
  on public.erp_studio_audit_log(company_id, created_at desc);

alter table public.erp_studio_designs enable row level security;
alter table public.erp_studio_design_versions enable row level security;
alter table public.erp_studio_audit_log enable row level security;

drop policy if exists erp_studio_designs_read_member on public.erp_studio_designs;
create policy erp_studio_designs_read_member on public.erp_studio_designs
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_studio_designs_insert_admin on public.erp_studio_designs;
create policy erp_studio_designs_insert_admin on public.erp_studio_designs
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and created_by = auth.uid() and updated_by = auth.uid()
);

drop policy if exists erp_studio_designs_update_admin on public.erp_studio_designs;
create policy erp_studio_designs_update_admin on public.erp_studio_designs
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and updated_by = auth.uid()
);

drop policy if exists erp_studio_designs_delete_admin on public.erp_studio_designs;
create policy erp_studio_designs_delete_admin on public.erp_studio_designs
for delete to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and status in ('draft','archived')
);

drop policy if exists erp_studio_versions_read_member on public.erp_studio_design_versions;
create policy erp_studio_versions_read_member on public.erp_studio_design_versions
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_studio_versions_insert_admin on public.erp_studio_design_versions;
create policy erp_studio_versions_insert_admin on public.erp_studio_design_versions
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and created_by = auth.uid()
  and exists (
    select 1 from public.erp_studio_designs d
    where d.id = design_id and d.company_id = erp_studio_design_versions.company_id
  )
);

drop policy if exists erp_studio_audit_read_admin on public.erp_studio_audit_log;
create policy erp_studio_audit_read_admin on public.erp_studio_audit_log
for select to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_studio_audit_insert_admin on public.erp_studio_audit_log;
create policy erp_studio_audit_insert_admin on public.erp_studio_audit_log
for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and actor_user_id = auth.uid()
);

revoke all on public.erp_studio_designs, public.erp_studio_design_versions, public.erp_studio_audit_log from anon, authenticated;
grant select, delete on public.erp_studio_designs to authenticated;
grant select on public.erp_studio_design_versions to authenticated;
grant select on public.erp_studio_audit_log to authenticated;
-- All writes and status transitions must pass through the checked RPC functions.

-- All design mutations are transactional and use optimistic revision checks.
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
language plpgsql
security definer
set search_path = public
set row_security = off
as $studio$
declare
  v_id uuid;
  v_revision integer;
begin
  if auth.uid() is null or not public.erp_user_has_company_role(
    p_company_id, array['owner','admin']::text[]
  ) then
    raise exception 'غير مصرح بحفظ تصميمات الاستوديو لهذه الشركة';
  end if;
  if p_name is null or length(trim(p_name)) not between 1 and 160
     or p_design_key is null or length(trim(p_design_key)) not between 1 and 120
     or p_schema_version < 1
     or jsonb_typeof(p_design_json) <> 'object'
     or jsonb_typeof(p_binding_json) <> 'object' then
    raise exception 'بيانات التصميم غير صالحة';
  end if;

  if p_design_id is null then
    insert into public.erp_studio_designs(
      company_id, design_key, name, design_kind, schema_version,
      status, design_json, binding_json, revision, created_by, updated_by
    ) values (
      p_company_id, trim(p_design_key), trim(p_name), p_design_kind,
      p_schema_version, 'draft', p_design_json, p_binding_json, 1,
      auth.uid(), auth.uid()
    ) returning id, revision into v_id, v_revision;
  else
    update public.erp_studio_designs
       set name = trim(p_name),
           design_kind = p_design_kind,
           schema_version = p_schema_version,
           status = 'draft',
           design_json = p_design_json,
           binding_json = p_binding_json,
           revision = revision + 1,
           updated_by = auth.uid(),
           updated_at = now()
     where id = p_design_id
       and company_id = p_company_id
       and revision = p_expected_revision
     returning id, revision into v_id, v_revision;
    if v_id is null then
      raise exception 'تعارض إصدار: أعد تحميل التصميم قبل الحفظ' using errcode = '40001';
    end if;
  end if;

  insert into public.erp_studio_design_versions(
    design_id, company_id, revision, design_json, binding_json,
    change_note, created_by
  ) values (
    v_id, p_company_id, v_revision, p_design_json, p_binding_json,
    p_change_note, auth.uid()
  );

  insert into public.erp_studio_audit_log(company_id, design_id, action_key, details, actor_user_id)
  values (p_company_id, v_id, 'save_draft', jsonb_build_object('revision', v_revision), auth.uid());

  return v_id;
end;
$studio$;

create or replace function public.erp_studio_approve_design(
  p_company_id uuid,
  p_design_id uuid,
  p_expected_revision integer
) returns boolean
language plpgsql
security definer
set search_path = public
set row_security = off
as $studio$
declare v_revision integer;
begin
  if auth.uid() is null or not public.erp_user_has_company_role(
    p_company_id, array['owner','admin']::text[]
  ) then raise exception 'غير مصرح باعتماد التصميم'; end if;

  update public.erp_studio_designs
     set status = 'approved', updated_by = auth.uid(), updated_at = now()
   where id = p_design_id and company_id = p_company_id
     and revision = p_expected_revision and status in ('draft','review')
   returning revision into v_revision;
  if v_revision is null then raise exception 'تعذر الاعتماد: الإصدار تغير أو الحالة غير مناسبة'; end if;

  insert into public.erp_studio_audit_log(company_id, design_id, action_key, details, actor_user_id)
  values (p_company_id, p_design_id, 'approve', jsonb_build_object('revision', v_revision), auth.uid());
  return true;
end;
$studio$;

create or replace function public.erp_studio_publish_design(
  p_company_id uuid,
  p_design_id uuid,
  p_tested_revision integer
) returns boolean
language plpgsql
security definer
set search_path = public
set row_security = off
as $studio$
declare v_revision integer;
begin
  if auth.uid() is null or not public.erp_user_has_company_role(
    p_company_id, array['owner','admin']::text[]
  ) then raise exception 'غير مصرح بنشر التصميم'; end if;

  update public.erp_studio_designs
     set status = 'published', published_revision = revision,
         updated_by = auth.uid(), updated_at = now()
   where id = p_design_id and company_id = p_company_id
     and revision = p_tested_revision and status = 'approved'
   returning revision into v_revision;
  if v_revision is null then
    raise exception 'لا يمكن النشر: يجب اعتماد الإصدار الحالي واختباره أولاً';
  end if;

  insert into public.erp_studio_audit_log(company_id, design_id, action_key, details, actor_user_id)
  values (p_company_id, p_design_id, 'publish', jsonb_build_object('revision', v_revision), auth.uid());
  return true;
end;
$studio$;

create or replace function public.erp_studio_restore_version(
  p_company_id uuid,
  p_design_id uuid,
  p_target_revision integer,
  p_expected_revision integer
) returns integer
language plpgsql
security definer
set search_path = public
set row_security = off
as $studio$
declare
  v_json jsonb;
  v_binding jsonb;
  v_new_revision integer;
begin
  if auth.uid() is null or not public.erp_user_has_company_role(
    p_company_id, array['owner','admin']::text[]
  ) then raise exception 'غير مصرح باستعادة إصدار'; end if;

  select design_json, binding_json into v_json, v_binding
    from public.erp_studio_design_versions
   where design_id = p_design_id and company_id = p_company_id
     and revision = p_target_revision;
  if v_json is null then raise exception 'الإصدار المطلوب غير موجود'; end if;

  update public.erp_studio_designs
     set design_json = v_json, binding_json = v_binding,
         revision = revision + 1, status = 'draft',
         updated_by = auth.uid(), updated_at = now()
   where id = p_design_id and company_id = p_company_id
     and revision = p_expected_revision
   returning revision into v_new_revision;
  if v_new_revision is null then
    raise exception 'تعارض إصدار أثناء الاستعادة؛ أعد تحميل التصميم' using errcode = '40001';
  end if;

  insert into public.erp_studio_design_versions(
    design_id, company_id, revision, design_json, binding_json, change_note, created_by
  ) values (
    p_design_id, p_company_id, v_new_revision, v_json, v_binding,
    'استعادة من الإصدار ' || p_target_revision, auth.uid()
  );

  insert into public.erp_studio_audit_log(company_id, design_id, action_key, details, actor_user_id)
  values (p_company_id, p_design_id, 'restore_version',
    jsonb_build_object('source_revision', p_target_revision, 'new_revision', v_new_revision), auth.uid());
  return v_new_revision;
end;
$studio$;

revoke all on function public.erp_studio_save_draft(uuid,uuid,text,text,text,integer,jsonb,jsonb,integer,text) from public, anon;
revoke all on function public.erp_studio_approve_design(uuid,uuid,integer) from public, anon;
revoke all on function public.erp_studio_publish_design(uuid,uuid,integer) from public, anon;
revoke all on function public.erp_studio_restore_version(uuid,uuid,integer,integer) from public, anon;
grant execute on function public.erp_studio_save_draft(uuid,uuid,text,text,text,integer,jsonb,jsonb,integer,text) to authenticated;
grant execute on function public.erp_studio_approve_design(uuid,uuid,integer) to authenticated;
grant execute on function public.erp_studio_publish_design(uuid,uuid,integer) to authenticated;
grant execute on function public.erp_studio_restore_version(uuid,uuid,integer,integer) to authenticated;

commit;
