do $$
declare v_def text;
begin
 v_def:=pg_get_functiondef('public.erp_recalculate_payroll_run(uuid)'::regprocedure);
 if position('max(s.salary_element_id)' in v_def)>0 then
   v_def:=replace(v_def,'max(s.salary_element_id)','(array_agg(s.salary_element_id order by s.created_at))[1]');
   execute v_def;
 elsif position('array_agg(s.salary_element_id order by s.created_at)' in v_def)=0 then
   raise exception 'Expected payroll settlement aggregation expression was not found';
 end if;
end $$;