
insert into public.erp_hr_salary_elements(company_id,element_code,name_ar,name_en,element_type,value_mode,nature,default_value,show_on_payslip,is_active)
select c.id,v.code,v.ar,v.en,v.kind,v.mode,v.nature,0,true,true
from public.erp_companies c
cross join (values
 ('SAL0004','الراتب الأساسي','Basic Salary','earning','fixed','value'),
 ('SAL0008','بدل سكن','Housing Allowance','earning','fixed','value'),
 ('SAL0025','بدل انتقال','Transportation Allowance','earning','fixed','value'),
 ('SAL0012','بدل وجبة','Meal Allowance','earning','fixed','value'),
 ('SAL0018','بدل اتصالات','Communication Allowance','earning','fixed','value'),
 ('SAL0022','بدل وردية','Shift Allowance','earning','fixed','value'),
 ('SAL0021','بدل طبيعة عمل','Work Nature Allowance','earning','fixed','value'),
 ('SAL0016','إضافي ساعات عمل','Overtime','earning','variable','time'),
 ('SAL0006','عمولة مبيعات','Sales Commission','earning','variable','value'),
 ('SAL0005','مكافأة أداء','Performance Bonus','earning','variable','value'),
 ('SAL0020','حافز أرباح','Profit Sharing','earning','variable','value'),
 ('SAL0003','حافز انتظام','Attendance Incentive','earning','variable','value'),
 ('SAL0023','تأمينات اجتماعية','Social Insurance','deduction','variable','value'),
 ('SAL0024','ضريبة كسب عمل','Payroll Tax','deduction','variable','value'),
 ('SAL0002','خصم سلفة','Salary Advance Recovery','deduction','variable','value'),
 ('SAL0001','خصم غياب','Absence Deduction','deduction','variable','days'),
 ('SAL0010','خصم تأخير','Late Deduction','deduction','variable','time'),
 ('SAL0017','جزاءات','Penalties','deduction','variable','value'),
 ('SAL0028','خصم إجازة بدون أجر','Unpaid Leave','deduction','variable','days'),
 ('SAL0015','استقطاعات أخرى','Other Deductions','deduction','variable','value')
) as v(code,ar,en,kind,mode,nature)
where not exists(select 1 from public.erp_hr_salary_elements e where e.company_id=c.id and e.element_code=v.code);
