CREATE OR REPLACE FUNCTION public.erp_add_payroll_line_and_recalculate(p_company_id uuid, p_run_id uuid, p_employee_id uuid, p_basic numeric, p_allowances numeric, p_commissions numeric, p_overtime_amount numeric, p_deductions numeric, p_element_values jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_run public.erp_payroll_runs%rowtype;
  v_employee public.erp_employees%rowtype;
  v_basic numeric(14,2);
  v_allowances numeric(14,2);
  v_commissions numeric(14,2);
  v_overtime numeric(14,2);
  v_base_deductions numeric(14,2);
  v_element_earnings numeric(14,2) := 0;
  v_element_deductions numeric(14,2) := 0;
  v_gross numeric(14,2);
  v_total_deductions numeric(14,2);
  v_net numeric(14,2);
  v_line_id uuid;
  v_run_id uuid;
begin
  if auth.uid() is null then
    raise exception 'يلزم تسجيل الدخول' using errcode='28000';
  end if;
  if p_company_id is null or p_run_id is null or p_employee_id is null then
    raise exception 'الشركة والمسير والموظف مطلوبة' using errcode='22023';
  end if;
  if p_element_values is null or jsonb_typeof(p_element_values)<>'object' then
    raise exception 'قيم عناصر المرتب يجب أن تكون كائنًا' using errcode='22023';
  end if;
  if jsonb_object_length(p_element_values)>200 then
    raise exception 'عدد عناصر المرتب يتجاوز الحد المسموح' using errcode='22023';
  end if;

  if coalesce(p_basic,0)<0 or coalesce(p_allowances,0)<0
     or coalesce(p_commissions,0)<0 or coalesce(p_overtime_amount,0)<0
     or coalesce(p_deductions,0)<0 then
    raise exception 'مبالغ الراتب والاستقطاعات لا يمكن أن تكون سالبة' using errcode='22023';
  end if;

  if not public.erp_user_has_company_role(
    p_company_id,array['owner','admin','accountant']::text[]
  ) then
    raise exception 'لا تملك صلاحية إضافة تفاصيل مسير الرواتب' using errcode='42501';
  end if;

  select r.* into v_run
  from public.erp_payroll_runs r
  where r.id=p_run_id and r.company_id=p_company_id
  for update;
  if not found then
    raise exception 'مسير الرواتب غير موجود في الشركة المحددة' using errcode='P0002';
  end if;
  if v_run.status<>'draft' then
    raise exception 'يمكن إضافة موظفين إلى مسودة الرواتب فقط' using errcode='23514';
  end if;

  select e.* into v_employee
  from public.erp_employees e
  where e.id=p_employee_id
    and e.company_id=p_company_id
    and e.is_active=true
    and e.employment_status='active'
;
  if not found then
    raise exception 'الموظف غير نشط أو لا يتبع الشركة المحددة' using errcode='23503';
  end if;

  if exists (
    select 1
    from jsonb_each_text(p_element_values) kv
    left join public.erp_hr_salary_elements se
      on se.id=kv.key::uuid
     and se.company_id=p_company_id
     and se.is_active=true
    where se.id is null
       or nullif(kv.value,'') is null
       or kv.value::numeric<0
       or kv.value::numeric>999.999
  ) then
    raise exception 'يوجد عنصر مرتب غير نشط أو لا يتبع الشركة أو قيمته خارج الحدود' using errcode='22023';
  end if;

  select
    coalesce(round(sum(kv.value::numeric) filter (
      where se.nature='value' and se.element_type='earning'
    ),2),0),
    coalesce(round(sum(kv.value::numeric) filter (
      where se.nature='value' and se.element_type='deduction'
    ),2),0)
  into v_element_earnings,v_element_deductions
  from jsonb_each_text(p_element_values) kv
  join public.erp_hr_salary_elements se
    on se.id=kv.key::uuid
   and se.company_id=p_company_id
   and se.is_active=true;

  v_basic:=round(coalesce(p_basic,0),2);
  v_allowances:=round(coalesce(p_allowances,0),2);
  v_commissions:=round(coalesce(p_commissions,0),2);
  v_overtime:=round(coalesce(p_overtime_amount,0),2);
  v_base_deductions:=round(coalesce(p_deductions,0),2);

  v_gross:=v_basic+v_allowances+v_commissions+v_overtime+v_element_earnings;
  v_total_deductions:=v_base_deductions+v_element_deductions;
  v_net:=v_gross-v_total_deductions;

  if v_total_deductions>v_gross or v_gross<0 or v_net<0 then
    raise exception 'إجمالي الاستقطاعات لا يمكن أن يتجاوز إجمالي المستحقات' using errcode='23514';
  end if;

  insert into public.erp_payroll_lines(
    company_id,payroll_run_id,employee_id,basic_amount,allowances,
    commissions,overtime_amount,deductions,gross_amount,net_amount,element_values
  )
  values(
    p_company_id,p_run_id,p_employee_id,v_basic,v_allowances,
    v_commissions,v_overtime,v_total_deductions,v_gross,v_net,p_element_values
  )
  returning id into v_line_id;

  v_run_id:=public.erp_recalculate_payroll_run(p_run_id);

  return jsonb_build_object(
    'line_id',v_line_id,
    'run_id',v_run_id,
    'gross_amount',v_gross,
    'deductions',v_total_deductions,
    'net_amount',v_net
  );
end;
$function$

revoke all on function public.erp_add_payroll_line_and_recalculate(uuid,uuid,uuid,numeric,numeric,numeric,numeric,numeric,jsonb) from public;
revoke all on function public.erp_add_payroll_line_and_recalculate(uuid,uuid,uuid,numeric,numeric,numeric,numeric,numeric,jsonb) from anon;
grant execute on function public.erp_add_payroll_line_and_recalculate(uuid,uuid,uuid,numeric,numeric,numeric,numeric,numeric,jsonb) to authenticated;
;

revoke all on function public.erp_add_payroll_line_and_recalculate(uuid,uuid,uuid,numeric,numeric,numeric,numeric,numeric,jsonb) from public;
revoke all on function public.erp_add_payroll_line_and_recalculate(uuid,uuid,uuid,numeric,numeric,numeric,numeric,numeric,jsonb) from anon;
grant execute on function public.erp_add_payroll_line_and_recalculate(uuid,uuid,uuid,numeric,numeric,numeric,numeric,numeric,jsonb) to authenticated;
