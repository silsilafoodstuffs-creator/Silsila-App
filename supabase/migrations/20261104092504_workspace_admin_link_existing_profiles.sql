-- Admin-only linking of existing registered accounts to existing Silsila activities.
-- Does not create an activity type or allow platform observers to post workspace movements.

create or replace function public.erp_admin_list_unlinked_activity_accounts()
returns table (
  profile_id uuid,
  full_name text,
  phone text,
  account_type text,
  role text,
  account_status text,
  activity_type text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_silsila_platform_user((select auth.uid())) then
    raise exception 'غير مصرح: هذه الوظيفة لموظفي إدارة سلسلة فقط';
  end if;
  return query
  select p.id, p.full_name, p.phone, p.account_type, p.role, p.account_status, p.activity_type
  from public.profiles p
  where lower(coalesce(p.role,'')) in ('customer','supplier','delegate','shipping_company')
    and lower(coalesce(p.account_type,'')) not in ('admin','administrator','super_admin','superadmin','إدارة نشاط','activity_manager','business_owner')
    and lower(coalesce(p.account_status,'')) in ('pending','approved','active','مفعل','معتمد','قيد المراجعة','معلق')
    and not exists (
      select 1 from public.erp_business_workspaces w
      where w.linked_profile_id=p.id and w.is_active
    )
  order by p.created_at desc;
end;
$$;

create or replace function public.erp_admin_link_existing_activity_account(p_profile_id uuid, p_activity_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_activity_code text;
  v_workspace_id uuid;
  v_role text;
  v_status text;
begin
  if not private.is_silsila_platform_user((select auth.uid())) then
    raise exception 'غير مصرح: ربط الحسابات متاح لإدارة سلسلة فقط';
  end if;

  select a.code into v_activity_code
  from public.activity_types a
  where a.is_active and lower(btrim(a.code))=lower(btrim(coalesce(p_activity_code,'')))
  limit 1;
  if v_activity_code is null then raise exception 'نوع النشاط غير موجود أو غير نشط'; end if;

  select lower(coalesce(p.role,'')), lower(coalesce(p.account_status,''))
    into v_role, v_status
  from public.profiles p where p.id=p_profile_id for update;
  if not found then raise exception 'الحساب المطلوب غير موجود'; end if;
  if v_role not in ('customer','supplier','delegate','shipping_company') then
    raise exception 'نوع الحساب غير مؤهل لربط مساحة نشاط';
  end if;
  if v_status not in ('pending','approved','active','مفعل','معتمد','قيد المراجعة','معلق') then
    raise exception 'حالة الحساب لا تسمح بالربط';
  end if;
  if exists (select 1 from public.erp_business_workspaces w where w.linked_profile_id=p_profile_id and w.is_active) then
    raise exception 'هذا الحساب مرتبط بالفعل بمساحة نشاط';
  end if;

  update public.profiles
  set activity_type=v_activity_code, account_status='approved', updated_at=now()
  where id=p_profile_id;

  select w.id into v_workspace_id
  from public.erp_business_workspaces w
  where w.linked_profile_id=p_profile_id and w.is_active
  order by w.created_at desc limit 1;
  if v_workspace_id is null then
    raise exception 'لم يتم إنشاء الربط تلقائياً. راجع بيانات الحساب ونوع النشاط وإعداد التهيئة';
  end if;
  return v_workspace_id;
end;
$$;

revoke all on function public.erp_admin_list_unlinked_activity_accounts() from public, anon;
revoke all on function public.erp_admin_link_existing_activity_account(uuid,text) from public, anon;
grant execute on function public.erp_admin_list_unlinked_activity_accounts() to authenticated;
grant execute on function public.erp_admin_link_existing_activity_account(uuid,text) to authenticated;
