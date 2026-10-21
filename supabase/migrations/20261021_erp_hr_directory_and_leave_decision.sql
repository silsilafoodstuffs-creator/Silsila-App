
create or replace view public.erp_employee_directory with (security_invoker = true) as
select e.id,e.company_id,e.branch_id,e.employee_code,e.full_name,e.phone,e.email,
       e.job_title,e.department_name,e.hire_date,e.employment_status,e.is_active
from public.erp_employees e
where public.erp_user_can_access_company(e.company_id) and e.is_active = true;

create or replace function public.erp_decide_leave_request(p_request_id uuid, p_decision text)
returns void language plpgsql security definer set search_path = public set row_security = off as $$
declare v_company_id uuid; v_status text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولًا'; end if;
  if p_decision not in ('approved','rejected','cancelled') then raise exception 'قرار الإجازة غير مدعوم'; end if;
  select company_id,status into v_company_id,v_status from public.erp_leave_requests where id=p_request_id for update;
  if not found then raise exception 'طلب الإجازة غير موجود'; end if;
  if not public.erp_user_has_company_role(v_company_id,array['owner','admin','manager']::text[]) then
    raise exception 'ليست لديك صلاحية اتخاذ قرار بشأن الإجازة';
  end if;
  if v_status <> 'pending' then raise exception 'لا يمكن تعديل طلب إجازة إلا إذا كان معلقًا'; end if;
  update public.erp_leave_requests
  set status=p_decision,
      approved_by=case when p_decision in ('approved','rejected') then auth.uid() else null end,
      approved_at=case when p_decision in ('approved','rejected') then now() else null end,
      updated_at=now()
  where id=p_request_id;
end;
$$;
revoke all on function public.erp_decide_leave_request(uuid,text) from public, anon;
grant execute on function public.erp_decide_leave_request(uuid,text) to authenticated;
