create or replace function public.erp_update_cheque_details(
  p_cheque_id uuid,p_issue_date date,p_due_date date,p_amount numeric,
  p_payee_type text,p_payee_name text,p_notes text default ''
) returns void language plpgsql security invoker set search_path=public as $$
declare c public.erp_cheques%rowtype; v_roles text[]; v_date_roles text[];
begin
  select * into c from public.erp_cheques where id=p_cheque_id for update;
  if not found then raise exception 'الشيك غير موجود'; end if;
  if c.status in ('paid','returned','cashed_from_cashbox','cancelled') then raise exception 'لا يمكن تعديل شيك تمت تسويته أو إلغاؤه'; end if;
  select cheque_edit_roles,cheque_issue_date_edit_roles into v_roles,v_date_roles from public.erp_financial_policies where company_id=c.company_id;
  if not public.erp_user_has_company_role(c.company_id,coalesce(v_roles,array['owner','admin','accountant']::text[])) then raise exception 'ليست لديك صلاحية تعديل بيانات الشيك'; end if;
  if p_issue_date is null or p_due_date is null or p_due_date<p_issue_date or p_amount is null or p_amount<=0 then raise exception 'راجع تاريخ الإصدار والاستحقاق والقيمة'; end if;
  if p_issue_date<>c.issue_date and not public.erp_user_has_company_role(c.company_id,coalesce(v_date_roles,array['owner','admin','accountant']::text[])) then raise exception 'تعديل تاريخ إصدار الشيك غير مسموح لهذا المستخدم'; end if;
  update public.erp_cheques set issue_date=p_issue_date,due_date=p_due_date,amount=p_amount,payee_type=p_payee_type,
    payee_name=coalesce(p_payee_name,''),notes=coalesce(p_notes,''),updated_by=auth.uid(),updated_at=now() where id=c.id;
end; $$;
revoke all on function public.erp_update_cheque_details(uuid,date,date,numeric,text,text,text) from public,anon;
grant execute on function public.erp_update_cheque_details(uuid,date,date,numeric,text,text,text) to authenticated;
