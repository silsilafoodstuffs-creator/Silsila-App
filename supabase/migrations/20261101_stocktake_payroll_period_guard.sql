do $$
declare v_def text;
begin
 v_def:=pg_get_functiondef('public.erp_recalculate_payroll_run(uuid)'::regprocedure);
 if position('and s.created_at::date<=v_run.period_end' in v_def)=0 then
   v_def:=replace(v_def,'and s.payroll_line_id is null','and s.payroll_line_id is null and s.created_at::date<=v_run.period_end');
   execute v_def;
 end if;
end $$;