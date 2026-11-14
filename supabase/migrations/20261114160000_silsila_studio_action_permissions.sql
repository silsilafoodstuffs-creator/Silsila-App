-- Action-level authorization for Silsila Studio.
-- Apply only after reviewing the permission matrix and validating against the target schema.
begin;

create or replace function public.erp_studio_has_action_permission(
  p_company_id uuid,
  p_action text
) returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public
set row_security = off
as $studio$
declare
  v_allowed boolean;
begin
  if auth.uid() is null or p_company_id is null then
    return false;
  end if;

  if public.erp_user_has_company_role(
    p_company_id, array['owner','admin']::text[]
  ) then
    return true;
  end if;

  if not public.erp_user_can_access_company(p_company_id) then
    return false;
  end if;

  select
    coalesce(pm.can_access, false)
    and case p_action
      when 'read' then true
      when 'published_read' then true
      when 'save' then coalesce(pm.can_save, false)
      when 'approve' then coalesce(pm.can_edit, false)
      when 'publish' then coalesce(pm.can_edit, false)
      when 'restore' then coalesce(pm.can_edit, false)
      when 'layout_save' then coalesce(pm.can_save, false)
      when 'layout_delete' then coalesce(pm.can_delete, false)
      else false
    end
  into v_allowed
  from public.erp_user_permission_matrix pm
  where pm.company_id = p_company_id
    and pm.user_id = auth.uid()
    and pm.menu_name = 'إعدادات عامة'
    and pm.submenu_name = 'بيانات أساسية'
    and pm.page_name = case when p_action = 'published_read' then 'شاشات الاستوديو المنشورة' else 'سلسلة ستوديو' end
  limit 1;

  return coalesce(v_allowed, false);
end;
$studio$;

revoke all on function public.erp_studio_has_action_permission(uuid,text)
  from public, anon;
grant execute on function public.erp_studio_has_action_permission(uuid,text)
  to authenticated;

-- Keep the mutation surface inside checked RPCs. SECURITY DEFINER is narrowly
-- scoped, has a fixed search_path, and validates company membership + action.
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
set search_path = pg_catalog, public
set row_security = off
as $studio$
declare
  v_id uuid;
  v_revision integer;
begin
  if not public.erp_studio_has_action_permission(p_company_id, 'save') then
    raise exception 'غير مصرح بحفظ تصميمات الاستوديو لهذه الشركة';
  end if;

  if p_name is null or length(trim(p_name)) not between 1 and 160
     or p_design_key is null or length(trim(p_design_key)) not between 1 and 120
     or p_schema_version is null or p_schema_version < 1
     or p_design_kind not in ('screen','report','icon','tree','table','grid','form','component')
     or jsonb_typeof(p_design_json) is distinct from 'object'
     or jsonb_typeof(p_binding_json) is distinct from 'object' then
    raise exception 'بيانات التصميم غير صالحة';
  end if;

  if octet_length(p_design_json::text) > 1048576
     or octet_length(p_binding_json::text) > 262144 then
    raise exception 'حجم مستند التصميم أو تعريفات الربط تجاوز الحد المسموح';
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
set search_path = pg_catalog, public
set row_security = off
as $studio$
declare v_revision integer;
begin
  if not public.erp_studio_has_action_permission(p_company_id, 'approve') then
    raise exception 'غير مصرح باعتماد التصميم';
  end if;

  update public.erp_studio_designs
     set status = 'approved', updated_by = auth.uid(), updated_at = now()
   where id = p_design_id and company_id = p_company_id
     and revision = p_expected_revision and status in ('draft','review')
   returning revision into v_revision;
  if v_revision is null then
    raise exception 'تعذر الاعتماد: الإصدار تغير أو الحالة غير مناسبة';
  end if;

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
set search_path = pg_catalog, public
set row_security = off
as $studio$
declare v_revision integer;
begin
  if not public.erp_studio_has_action_permission(p_company_id, 'publish') then
    raise exception 'غير مصرح بنشر التصميم';
  end if;

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
set search_path = pg_catalog, public
set row_security = off
as $studio$
declare
  v_json jsonb;
  v_binding jsonb;
  v_new_revision integer;
begin
  if not public.erp_studio_has_action_permission(p_company_id, 'restore') then
    raise exception 'غير مصرح باستعادة إصدار';
  end if;

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


-- Read access is also action-scoped: ordinary company members must not be
-- able to enumerate unpublished drafts or their historical revisions.
drop policy if exists erp_studio_designs_read_member on public.erp_studio_designs;
create policy erp_studio_designs_read_permission
on public.erp_studio_designs
for select to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  or public.erp_studio_has_action_permission(company_id, 'read')
  or (
    coalesce(published_revision, 0) > 0
    and public.erp_studio_has_action_permission(company_id, 'published_read')
  )
);

drop policy if exists erp_studio_versions_read_member on public.erp_studio_design_versions;
create policy erp_studio_versions_read_permission
on public.erp_studio_design_versions
for select to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  or public.erp_studio_has_action_permission(company_id, 'read')
  or (
    public.erp_studio_has_action_permission(company_id, 'published_read')
    and exists (
      select 1
      from public.erp_studio_designs d
      where d.id = erp_studio_design_versions.design_id
        and d.company_id = erp_studio_design_versions.company_id
        and d.published_revision = erp_studio_design_versions.revision
    )
  )
);

drop policy if exists erp_studio_layout_profiles_read_member
  on public.erp_studio_layout_profiles;
create policy erp_studio_layout_profiles_read_permission
on public.erp_studio_layout_profiles
for select to authenticated
using (
  public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  or public.erp_studio_has_action_permission(company_id, 'read')
);

-- Layout profiles are a separate mutable resource and use their own action grants.
drop policy if exists erp_studio_layout_profiles_insert_admin
  on public.erp_studio_layout_profiles;
create policy erp_studio_layout_profiles_insert_permission
on public.erp_studio_layout_profiles
for insert to authenticated
with check (
  public.erp_studio_has_action_permission(company_id, 'layout_save')
  and updated_by = auth.uid()
);

drop policy if exists erp_studio_layout_profiles_update_admin
  on public.erp_studio_layout_profiles;
create policy erp_studio_layout_profiles_update_permission
on public.erp_studio_layout_profiles
for update to authenticated
using (public.erp_studio_has_action_permission(company_id, 'layout_save'))
with check (
  public.erp_studio_has_action_permission(company_id, 'layout_save')
  and updated_by = auth.uid()
);

drop policy if exists erp_studio_layout_profiles_delete_admin
  on public.erp_studio_layout_profiles;
create policy erp_studio_layout_profiles_delete_permission
on public.erp_studio_layout_profiles
for delete to authenticated
using (public.erp_studio_has_action_permission(company_id, 'layout_delete'));

-- RPC ownership, not direct table privileges, is the only route for ordinary
-- members to mutate design metadata. Existing owner/admin RLS remains in place.
revoke all on function public.erp_studio_save_draft(uuid,uuid,text,text,text,integer,jsonb,jsonb,integer,text)
  from public, anon;
revoke all on function public.erp_studio_approve_design(uuid,uuid,integer)
  from public, anon;
revoke all on function public.erp_studio_publish_design(uuid,uuid,integer)
  from public, anon;
revoke all on function public.erp_studio_restore_version(uuid,uuid,integer,integer)
  from public, anon;
grant execute on function public.erp_studio_save_draft(uuid,uuid,text,text,text,integer,jsonb,jsonb,integer,text)
  to authenticated;
grant execute on function public.erp_studio_approve_design(uuid,uuid,integer)
  to authenticated;
grant execute on function public.erp_studio_publish_design(uuid,uuid,integer)
  to authenticated;
grant execute on function public.erp_studio_restore_version(uuid,uuid,integer,integer)
  to authenticated;

commit;
