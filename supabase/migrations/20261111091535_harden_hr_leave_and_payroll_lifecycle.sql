CREATE OR REPLACE FUNCTION public.erp_create_leave_request(p_company_id uuid, p_employee_id uuid, p_leave_type text, p_starts_on date, p_ends_on date, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_employee public.erp_employees%rowtype;
  v_request_id uuid;
  v_days numeric(8,2);
begin
  if (select auth.uid()) is null then
    raise exception 'يجب تسجيل الدخول أولًا' using errcode='28000';
  end if;
  if p_company_id is null or p_employee_id is null
     or p_starts_on is null or p_ends_on is null then
    raise exception 'الشركة والموظف وتاريخا بداية ونهاية الإجازة مطلوبة' using errcode='22023';
  end if;
  if p_leave_type is null or p_leave_type not in (
    'سنوية','عارضة','مرضية','إصابة عمل','رسمية','بدون أجر'
  ) then
    raise exception 'نوع الإجازة غير مدعوم' using errcode='22023';
  end if;
  if p_ends_on<p_starts_on then
    raise exception 'تاريخ بداية الإجازة يجب ألا يتجاوز نهايتها' using errcode='22023';
  end if;
  if p_ends_on-p_starts_on+1>365 then
    raise exception 'مدة طلب الإجازة تتجاوز الحد المسموح للطلب الواحد' using errcode='22023';
  end if;
  if length(coalesce(p_reason,''))>2000 then
    raise exception 'سبب الإجازة يتجاوز الحد المسموح' using errcode='22023';
  end if;

  if not public.erp_user_has_company_role(
    p_company_id,array['owner','admin','manager','operator']::text[]
  ) then
    raise exception 'لا تملك صلاحية إنشاء طلب إجازة لهذه الشركة' using errcode='42501';
  end if;

  select e.* into v_employee
  from public.erp_employees e
  where e.id=p_employee_id
    and e.company_id=p_company_id
    and e.is_active=true
    and e.employment_status='active'
  for update;
  if not found then
    raise exception 'الموظف غير نشط أو لا يتبع الشركة المحددة' using errcode='23503';
  end if;

  if not public.erp_user_can_access_employee_scope(p_company_id,p_employee_id) then
    raise exception 'لا تملك صلاحية نطاق هذا الموظف لإنشاء طلب إجازة' using errcode='42501';
  end if;

  if exists (
    select 1
    from public.erp_leave_requests r
    where r.company_id=p_company_id
      and r.employee_id=p_employee_id
      and r.status in ('pending','approved')
      and daterange(r.starts_on,r.ends_on,'[]') && daterange(p_starts_on,p_ends_on,'[]')
  ) then
    raise exception 'يوجد طلب إجازة معلق أو معتمد يتداخل مع هذه الفترة للموظف' using errcode='23505';
  end if;

  v_days:=(p_ends_on-p_starts_on+1)::numeric;
  insert into public.erp_leave_requests(
    company_id,employee_id,leave_type,starts_on,ends_on,requested_days,
    reason,status,approved_by,approved_at
  ) values (
    p_company_id,p_employee_id,p_leave_type,p_starts_on,p_ends_on,v_days,
    nullif(btrim(coalesce(p_reason,'')),''),'pending',null,null
  ) returning id into v_request_id;

  return v_request_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_decide_leave_request(p_request_id uuid, p_decision text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_company_id uuid;
  v_employee_id uuid;
  v_starts_on date;
  v_ends_on date;
  v_status text;
  v_employee public.erp_employees%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'يجب تسجيل الدخول أولًا' using errcode='28000';
  end if;
  if p_request_id is null or p_decision is null
     or p_decision not in ('approved','rejected','cancelled') then
    raise exception 'قرار الإجازة غير مدعوم' using errcode='22023';
  end if;

  select r.company_id,r.employee_id,r.starts_on,r.ends_on,r.status
    into v_company_id,v_employee_id,v_starts_on,v_ends_on,v_status
  from public.erp_leave_requests r
  where r.id=p_request_id
  for update;

  if not found then
    raise exception 'طلب الإجازة غير موجود' using errcode='P0002';
  end if;

  if not public.erp_user_has_company_role(
    v_company_id,array['owner','admin','manager']::text[]
  ) then
    raise exception 'ليست لديك صلاحية اتخاذ قرار بشأن الإجازة' using errcode='42501';
  end if;
  if not public.erp_user_can_access_employee_scope(v_company_id,v_employee_id) then
    raise exception 'لا تملك صلاحية نطاق الموظف صاحب طلب الإجازة' using errcode='42501';
  end if;
  if v_status<>'pending' then
    raise exception 'لا يمكن تعديل طلب إجازة إلا إذا كان معلقًا' using errcode='23514';
  end if;

  if p_decision='approved' then
    select e.* into v_employee
    from public.erp_employees e
    where e.id=v_employee_id
      and e.company_id=v_company_id
      and e.is_active=true
      and e.employment_status='active'
    for update;
    if not found then
      raise exception 'لا يمكن اعتماد إجازة لموظف غير نشط أو لا يتبع الشركة' using errcode='23503';
    end if;

    if exists (
      select 1
      from public.erp_leave_requests r
      where r.company_id=v_company_id
        and r.employee_id=v_employee_id
        and r.id<>p_request_id
        and r.status='approved'
        and daterange(r.starts_on,r.ends_on,'[]') && daterange(v_starts_on,v_ends_on,'[]')
    ) then
      raise exception 'يتداخل طلب الإجازة مع إجازة معتمدة أخرى للموظف' using errcode='23505';
    end if;
  end if;

  update public.erp_leave_requests
  set status=p_decision,
      approved_by=case when p_decision in ('approved','rejected') then (select auth.uid()) else null end,
      approved_at=case when p_decision in ('approved','rejected') then now() else null end,
      updated_at=now()
  where id=p_request_id
    and company_id=v_company_id
    and status='pending';
  if not found then
    raise exception 'تغيرت حالة طلب الإجازة أثناء اتخاذ القرار؛ حدّث الشاشة وأعد المحاولة' using errcode='40001';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_approve_payroll_run(p_run_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_run public.erp_payroll_runs%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'يلزم تسجيل الدخول' using errcode='28000';
  end if;
  select * into v_run
  from public.erp_payroll_runs
  where id=p_run_id
  for update;
  if not found then
    raise exception 'مسير الرواتب غير موجود' using errcode='P0002';
  end if;
  if not public.erp_user_has_company_role(v_run.company_id,array['owner','admin','accountant']::text[]) then
    raise exception 'لا تملك صلاحية اعتماد مسير الرواتب' using errcode='42501';
  end if;
  perform public.erp_recalculate_payroll_run(p_run_id);
  select * into v_run from public.erp_payroll_runs where id = p_run_id for update;
  if v_run.status <> 'draft' then raise exception 'يمكن اعتماد مسودة الرواتب فقط'; end if;
  if v_run.employee_count = 0 or v_run.gross_total <= 0 then
    raise exception 'لا يمكن اعتماد مسير رواتب بلا موظفين أو بقيمة صفرية';
  end if;
  update public.erp_payroll_runs
  set status = 'approved', approved_by = auth.uid(), approved_at = now(), updated_at = now()
  where id = v_run.id;
  return v_run.id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_recalculate_payroll_run(p_run_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_run public.erp_payroll_runs%rowtype;
  v_count integer;
  v_gross numeric(16,2);
  v_deductions numeric(16,2);
  v_net numeric(16,2);
  v_line record;
  v_amount numeric(16,2);
  v_element_id uuid;
  v_settlement_ids uuid[];
  v_values jsonb;
  v_existing numeric(16,2);
begin
  select * into v_run from public.erp_payroll_runs where id=p_run_id for update;
  if not found then raise exception 'مسير الرواتب غير موجود'; end if;
  if not public.erp_user_has_company_role(v_run.company_id,array['owner','admin','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية مراجعة مسير الرواتب';
  end if;
  if v_run.status<>'draft' then raise exception 'إعادة الحساب متاحة للمسودة فقط'; end if;

  -- Attach unallocated employee stocktake shortages to that employee's locked payroll element once.
  for v_line in
    select id,employee_id,gross_amount,deductions,net_amount,element_values
    from public.erp_payroll_lines
    where payroll_run_id=v_run.id and company_id=v_run.company_id
    order by created_at,id
    for update
  loop
    select coalesce(sum(s.amount),0)::numeric(16,2),
           (array_agg(s.salary_element_id order by s.created_at))[1],
           array_agg(s.id)
    into v_amount,v_element_id,v_settlement_ids
    from public.erp_stocktake_settlements s
    where s.company_id=v_run.company_id
      and s.target_type='employee'
      and s.target_id=v_line.employee_id
      and s.payroll_run_id is null and s.payroll_line_id is null and s.created_at::date<=v_run.period_end
      and s.salary_element_id is not null;
    if v_amount>0 then
      if v_line.net_amount<v_amount then
        raise exception 'قيمة عجز الجرد للموظف تتجاوز صافي مستحقاته في هذا المسير';
      end if;
      v_values:=coalesce(v_line.element_values,'{}'::jsonb);
      v_existing:=coalesce(nullif(v_values->>v_element_id::text,'')::numeric,0);
      update public.erp_payroll_lines
      set element_values=jsonb_set(v_values,array[v_element_id::text],to_jsonb(v_existing+v_amount),true),
          deductions=deductions+v_amount,
          net_amount=net_amount-v_amount
      where id=v_line.id;
      update public.erp_stocktake_settlements
      set payroll_run_id=v_run.id,payroll_line_id=v_line.id,payroll_applied_at=now()
      where id=any(v_settlement_ids);
    end if;
  end loop;

  select count(*)::integer,
    coalesce(sum(gross_amount),0)::numeric(16,2),
    coalesce(sum(deductions),0)::numeric(16,2),
    coalesce(sum(net_amount),0)::numeric(16,2)
  into v_count,v_gross,v_deductions,v_net
  from public.erp_payroll_lines where payroll_run_id=v_run.id;

  update public.erp_payroll_runs
  set employee_count=v_count,gross_total=v_gross,deduction_total=v_deductions,
      net_total=v_net,updated_at=now()
  where id=v_run.id;
  return v_run.id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_post_payroll_run(p_run_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_run public.erp_payroll_runs%rowtype;
  v_lines jsonb := '[]'::jsonb;
  v_journal_id uuid;
begin
  select * into v_run from public.erp_payroll_runs where id = p_run_id for update;
  if not found then raise exception 'مسير الرواتب غير موجود'; end if;
  if not public.erp_user_has_company_role(v_run.company_id, array['owner','admin','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية ترحيل الرواتب';
  end if;
  if v_run.status <> 'approved' then raise exception 'اعتمد مسير الرواتب قبل الترحيل'; end if;
  if v_run.journal_entry_id is not null then raise exception 'مسير الرواتب مرتبط بقيد بالفعل'; end if;
  if v_run.gross_total <= 0 or v_run.employee_count <= 0 then raise exception 'إجماليات مسير الرواتب غير صالحة'; end if;
  if v_run.expense_account_id is null then raise exception 'حدد حساب مصروف الرواتب'; end if;
  if v_run.net_total > 0 and v_run.payable_account_id is null then raise exception 'حدد حساب مستحقات الرواتب'; end if;
  if v_run.deduction_total > 0 and v_run.deductions_account_id is null then raise exception 'حدد حساب استقطاعات الرواتب'; end if;

  v_lines := v_lines || jsonb_build_array(jsonb_build_object(
    'account_id', v_run.expense_account_id,
    'description', 'مصروف مسير الرواتب ' || v_run.run_code,
    'debit', v_run.gross_total, 'credit', 0
  ));
  if v_run.net_total > 0 then
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_run.payable_account_id,
      'description', 'صافي مستحقات الرواتب ' || v_run.run_code,
      'debit', 0, 'credit', v_run.net_total
    ));
  end if;
  if v_run.deduction_total > 0 then
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_run.deductions_account_id,
      'description', 'استقطاعات مسير الرواتب ' || v_run.run_code,
      'debit', 0, 'credit', v_run.deduction_total
    ));
  end if;

  v_journal_id := public.erp_save_journal_draft(
    v_run.company_id, v_run.period_end, 'ترحيل مسير الرواتب ' || v_run.run_code, v_lines, null
  );
  perform public.erp_post_journal_entry(v_journal_id);

  update public.erp_payroll_runs
  set status = 'posted', journal_entry_id = v_journal_id, updated_at = now()
  where id = v_run.id;
  return v_journal_id;
end;
$function$
;
revoke all on function public.erp_create_leave_request(uuid,uuid,text,date,date,text) from public;
revoke all on function public.erp_create_leave_request(uuid,uuid,text,date,date,text) from anon;
grant execute on function public.erp_create_leave_request(uuid,uuid,text,date,date,text) to authenticated;

revoke all on function public.erp_decide_leave_request(uuid,text) from public;
revoke all on function public.erp_decide_leave_request(uuid,text) from anon;
grant execute on function public.erp_decide_leave_request(uuid,text) to authenticated;

revoke all on function public.erp_approve_payroll_run(uuid) from public;
revoke all on function public.erp_approve_payroll_run(uuid) from anon;
grant execute on function public.erp_approve_payroll_run(uuid) to authenticated;

revoke all on function public.erp_recalculate_payroll_run(uuid) from public;
revoke all on function public.erp_recalculate_payroll_run(uuid) from anon;
grant execute on function public.erp_recalculate_payroll_run(uuid) to authenticated;

revoke all on function public.erp_post_payroll_run(uuid) from public;
revoke all on function public.erp_post_payroll_run(uuid) from anon;
grant execute on function public.erp_post_payroll_run(uuid) to authenticated;
