create or replace function public.erp_register_checkbook(p_checkbook_id uuid)
returns integer language plpgsql security invoker set search_path=public as $$
declare b public.erp_checkbooks%rowtype; v_inserted integer;
begin
  select * into b from public.erp_checkbooks where id=p_checkbook_id for update;
  if not found then raise exception 'دفتر الشيكات غير موجود'; end if;
  if b.registered then raise exception 'تم تسجيل هذا الدفتر بالفعل'; end if;
  if not public.erp_user_has_company_role(b.company_id,array['owner','admin','manager','accountant']::text[]) then raise exception 'ليست لديك صلاحية تسجيل دفتر الشيكات'; end if;
  insert into public.erp_cheques(company_id,checkbook_id,bank_cashbox_id,check_number,cheque_type,direction,issue_date,amount,status,created_by)
  select b.company_id,b.id,b.bank_cashbox_id,b.first_check_number+g.n,'bank','payment',current_date,0.01,'available',auth.uid()
  from generate_series(0,b.sheet_count-1) as g(n);
  get diagnostics v_inserted=row_count;
  update public.erp_checkbooks set registered=true,registered_at=now() where id=b.id;
  return v_inserted;
end; $$;
revoke all on function public.erp_register_checkbook(uuid) from public,anon;
grant execute on function public.erp_register_checkbook(uuid) to authenticated;
