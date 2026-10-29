update public.erp_employees
set work_unit = case
  when lower(coalesce(job_title, '') || ' ' || coalesce(department_name, '')) ~ '(سائق|سواق|سيارات|نقل|أسطول|driver|vehicle|transport|fleet)'
    then 'سيارات'
  when lower(coalesce(job_title, '') || ' ' || coalesce(department_name, '')) ~ '(مخزن|مخازن|مستودع|أمين مخزن|مخزني|warehouse|storekeeper|inventory)'
    then 'مخازن'
  else 'مكتب إداري'
end
where work_unit = 'مكتب إداري';
