-- HR approval workflows. Apply after erp_hr_schema.sql and erp_security_membership.sql.

create or replace function public.erp_decide_leave_request(
  p_request_id uuid,
  p_decision text
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_request public.erp_leave_requests%rowtype;
begin
  if p_decision not in ('approved','rejected') then raise exception 'قرار الإجازة غير صالح'; end if;
  select * into v_request from public.erp_leave_requests where id = p_request_id for update;
  if not found then raise exception 'طلب الإجازة غير موجود'; end if;
  if not public.erp_user_has_company_role(v_request.company_id, array['owner','admin','manager']::text[]) then
    raise exception 'ليست لديك صلاحية اعتماد الإجازات';
  end if;
  if v_request.status <> 'pending' then raise exception 'يمكن اتخاذ قرار في الطلبات المعلقة فقط'; end if;
  update public.erp_leave_requests
  set status = p_decision, approved_by = auth.uid(), approved_at = now(), updated_at = now()
  where id = v_request.id;
  return v_request.id;
end;
$$;

revoke all on function public.erp_decide_leave_request(uuid,text) from public, anon;
grant execute on function public.erp_decide_leave_request(uuid,text) to authenticated;

