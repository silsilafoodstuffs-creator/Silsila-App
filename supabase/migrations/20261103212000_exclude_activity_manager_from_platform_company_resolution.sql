create or replace function private.silsila_platform_company_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select cm.company_id
  from public.erp_company_members cm
  join public.profiles p on p.id=cm.user_id
  where cm.is_active
    and p.role in ('management','admin')
    and p.account_status = any(array['approved','active','مفعل','معتمد']::text[])
    and lower(coalesce(p.account_type,'')) not in ('إدارة نشاط','activity_manager','business_owner')
  order by cm.created_at
  limit 1
$function$;
