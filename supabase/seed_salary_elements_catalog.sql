
insert into public.erp_hr_salary_elements(company_id,element_code,name_ar,name_en,element_type,value_mode,nature,default_value,show_on_payslip,is_active)
select c.id,v.code,v.ar,v.en,v.kind,v.mode,v.nature,0,true,true
from public.erp_companies c
cross join (values
 ('BASIC','الراتب الأساسي','Basic Salary','earning','fixed','value'),
 ('HOUSING','بدل سكن','Housing Allowance','earning','fixed','value'),
 ('TRANSPORT','بدل انتقال','Transportation Allowance','earning','fixed','value'),
 ('MEAL','بدل وجبة','Meal Allowance','earning','fixed','value'),
 ('PHONE','بدل اتصالات','Communication Allowance','earning','fixed','value'),
 ('SHIFT','بدل وردية','Shift Allowance','earning','fixed','value'),
 ('RISK','بدل طبيعة عمل','Work Nature Allowance','earning','fixed','value'),
 ('OVERTIME','إضافي ساعات عمل','Overtime','earning','variable','time'),
 ('COMMISSION','عمولة مبيعات','Sales Commission','earning','variable','value'),
 ('BONUS','مكافأة أداء','Performance Bonus','earning','variable','value'),
 ('PROFITSHARE','حافز أرباح','Profit Sharing','earning','variable','value'),
 ('ATTENDANCE','حافز انتظام','Attendance Incentive','earning','variable','value'),
 ('SOCIALINS','تأمينات اجتماعية','Social Insurance','deduction','variable','value'),
 ('TAX','ضريبة كسب عمل','Payroll Tax','deduction','variable','value'),
 ('ADVANCE','خصم سلفة','Salary Advance Recovery','deduction','variable','value'),
 ('ABSENCE','خصم غياب','Absence Deduction','deduction','variable','days'),
 ('LATE','خصم تأخير','Late Deduction','deduction','variable','time'),
 ('PENALTY','جزاءات','Penalties','deduction','variable','value'),
 ('UNPAIDLEAVE','خصم إجازة بدون أجر','Unpaid Leave','deduction','variable','days'),
 ('OTHERDEDUCT','استقطاعات أخرى','Other Deductions','deduction','variable','value')
) as v(code,ar,en,kind,mode,nature)
where not exists(select 1 from public.erp_hr_salary_elements e where e.company_id=c.id and e.element_code=v.code);
