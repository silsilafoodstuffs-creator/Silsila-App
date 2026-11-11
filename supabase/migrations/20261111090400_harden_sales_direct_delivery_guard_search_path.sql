CREATE OR REPLACE FUNCTION public.erp_guard_sales_direct_delivery()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_allowed boolean := false;
begin
  if new.kind <> 'delivery' or new.source_mode <> 'direct' then
    return new;
  end if;
  select m.member_role into v_role
  from public.erp_company_members m
  where m.company_id = new.company_id
    and m.user_id = (select auth.uid())
    and m.is_active = true
  limit 1;
  if v_role in ('owner', 'admin') then
    return new;
  end if;
  select coalesce(p.allow_access, false) and coalesce(p.can_edit, false)
    into v_allowed
  from public.erp_user_permissions p
  where p.company_id = new.company_id
    and p.user_id = (select auth.uid())
    and p.menu_key in ('مبيعات::حركات::إذن التسليم', 'المبيعات والعملاء::حركات::إذن التسليم')
  limit 1;
  if not coalesce(v_allowed, false) then
    raise exception 'التحميل بدون تجهيز يتطلب صلاحية تعديل إذن التسليم';
  end if;
  return new;
end;
$function$
;

revoke all on function public.erp_guard_sales_direct_delivery() from public;
revoke all on function public.erp_guard_sales_direct_delivery() from anon;
grant execute on function public.erp_guard_sales_direct_delivery() to authenticated;
