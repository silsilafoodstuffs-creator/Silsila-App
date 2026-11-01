alter table public.erp_stocktake_settlements
 add column if not exists payroll_run_id uuid references public.erp_payroll_runs(id) on delete set null,
 add column if not exists payroll_line_id uuid references public.erp_payroll_lines(id) on delete set null,
 add column if not exists payroll_applied_at timestamptz;

create index if not exists erp_stocktake_settlements_pending_payroll_idx
 on public.erp_stocktake_settlements(company_id,target_id,created_at)
 where target_type='employee' and payroll_line_id is null and salary_element_id is not null;

create or replace function public.erp_recalculate_payroll_run(p_run_id uuid)
returns uuid language plpgsql security definer set search_path='public' set row_security='off'
as $function$
declare
 v_run public.erp_payroll_runs%rowtype; v_count integer; v_gross numeric(16,2); v_deductions numeric(16,2); v_net numeric(16,2);
 v_line record; v_amount numeric(16,2); v_element_id uuid; v_settlement_ids uuid[]; v_values jsonb; v_existing numeric(16,2);
begin
 select * into v_run from public.erp_payroll_runs where id=p_run_id for update;
 if not found then raise exception 'مسير الرواتب غير موجود'; end if;
 if not public.erp_user_has_company_role(v_run.company_id,array['owner','admin','accountant']::text[]) then raise exception 'ليست لديك صلاحية مراجعة مسير الرواتب'; end if;
 if v_run.status<>'draft' then raise exception 'إعادة الحساب متاحة للمسودة فقط'; end if;
 for v_line in
   select id,employee_id,gross_amount,deductions,net_amount,element_values
   from public.erp_payroll_lines where payroll_run_id=v_run.id and company_id=v_run.company_id
   order by created_at,id for update
 loop
   select coalesce(sum(s.amount),0)::numeric(16,2),max(s.salary_element_id),array_agg(s.id)
   into v_amount,v_element_id,v_settlement_ids
   from public.erp_stocktake_settlements s
   where s.company_id=v_run.company_id and s.target_type='employee' and s.target_id=v_line.employee_id
     and s.payroll_line_id is null and s.salary_element_id is not null;
   if v_amount>0 then
     if v_line.net_amount<v_amount then raise exception 'قيمة عجز الجرد للموظف تتجاوز صافي مستحقاته في هذا المسير'; end if;
     v_values:=coalesce(v_line.element_values,'{}'::jsonb);
     v_existing:=coalesce(nullif(v_values->>v_element_id::text,'')::numeric,0);
     update public.erp_payroll_lines
       set element_values=jsonb_set(v_values,array[v_element_id::text],to_jsonb(v_existing+v_amount),true),
           deductions=deductions+v_amount,net_amount=net_amount-v_amount
       where id=v_line.id;
     update public.erp_stocktake_settlements
       set payroll_run_id=v_run.id,payroll_line_id=v_line.id,payroll_applied_at=now()
       where id=any(v_settlement_ids);
   end if;
 end loop;
 select count(*)::integer,coalesce(sum(gross_amount),0)::numeric(16,2),
        coalesce(sum(deductions),0)::numeric(16,2),coalesce(sum(net_amount),0)::numeric(16,2)
 into v_count,v_gross,v_deductions,v_net
 from public.erp_payroll_lines where payroll_run_id=v_run.id;
 update public.erp_payroll_runs set employee_count=v_count,gross_total=v_gross,
   deduction_total=v_deductions,net_total=v_net,updated_at=now() where id=v_run.id;
 return v_run.id;
end;
$function$;