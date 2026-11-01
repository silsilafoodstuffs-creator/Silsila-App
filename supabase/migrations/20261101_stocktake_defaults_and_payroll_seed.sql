-- Stocktake defaults and complete per-warehouse item setup.
-- Default unit is the largest selectable unit (highest conversion factor to base).
insert into public.erp_item_warehouse_settings
  (company_id,item_id,warehouse_id,purchase_unit_id,sale_unit_id,transfer_unit_id)
select i.company_id,i.id,w.id,u.id,u.id,u.id
from public.erp_items i
join public.erp_warehouses w on w.company_id=i.company_id and w.is_active=true
left join lateral (
  select iu.id
  from public.erp_item_units iu
  where iu.company_id=i.company_id and iu.item_id=i.id
    and iu.is_active=true and iu.is_selectable=true
  order by iu.conversion_factor desc, iu.is_base_unit asc, iu.created_at asc
  limit 1
) u on true
where i.is_active=true
on conflict (item_id,warehouse_id) do nothing;

-- Keep inventory valuation preference centralized and default it to sale price.
insert into public.erp_program_policies
  (company_id,policy_key,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value)
select c.id,'inventory.stocktake.valuation_basis','المخازن','أساس تقييم فروق الجرد','Stocktake variance valuation basis',true,true,'[]'::jsonb,'sale'
from public.erp_companies c
where not exists (
  select 1 from public.erp_program_policies p
  where p.company_id=c.id and p.policy_key='inventory.stocktake.valuation_basis'
);

-- Add common payroll components without overwriting company-customized rows.
insert into public.erp_hr_salary_elements
  (company_id,element_code,name_ar,name_en,element_type,value_mode,nature,default_value,show_on_payslip,is_active,is_system_locked)
select c.id,v.code,v.ar,v.en,v.typ,v.mode,v.nature,0,true,true,false
from public.erp_companies c
cross join (values
 ('SAL0014','بدل وردية ليلية','Night Shift Allowance','earning','fixed','value'),
 ('SAL0013','بدل وجبة إضافية','Overtime Meal Allowance','earning','variable','value'),
 ('SAL0026','بدل مأمورية وانتقال','Business Travel Allowance','earning','variable','value'),
 ('SAL0019','خصم اتصالات','Phone Deduction','deduction','variable','value'),
 ('SAL0011','خصم قرض موظف','Employee Loan Deduction','deduction','variable','value'),
 ('SAL0027','خصم عهدة أو زي','Uniform / Custody Deduction','deduction','variable','value'),
 ('SAL0007','أجر عمل أيام العطلات','Holiday Work Pay','earning','variable','days'),
 ('SAL0009','استقطاعات تأمينية أخرى','Other Insurance Deductions','deduction','variable','value')
) as v(code,ar,en,typ,mode,nature)
where not exists (
 select 1 from public.erp_hr_salary_elements e
 where e.company_id=c.id and e.element_code=v.code
);

create index if not exists erp_stocktake_lines_company_warehouse_item_idx
 on public.erp_stocktake_lines(company_id,warehouse_id,item_id);
create index if not exists erp_stocktakes_company_status_created_idx
 on public.erp_stocktakes(company_id,status,created_at desc);
