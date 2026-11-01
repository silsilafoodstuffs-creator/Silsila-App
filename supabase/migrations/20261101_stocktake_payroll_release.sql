do $$
declare v_def text;
begin
 v_def:=pg_get_functiondef('public.erp_recalculate_payroll_run(uuid)'::regprocedure);
 if position('and s.payroll_run_id is null' in v_def)=0 then
   v_def:=replace(v_def,'and s.payroll_line_id is null','and s.payroll_run_id is null and s.payroll_line_id is null');
   execute v_def;
 end if;
end $$;

create or replace function public.erp_release_stocktake_settlement_on_payroll_line_delete()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.erp_stocktake_settlements set payroll_run_id=null,payroll_line_id=null,payroll_applied_at=null where payroll_line_id=old.id;
 return old;
end $$;
drop trigger if exists trg_erp_release_stocktake_settlement_on_payroll_line_delete on public.erp_payroll_lines;
create trigger trg_erp_release_stocktake_settlement_on_payroll_line_delete before delete on public.erp_payroll_lines
for each row execute function public.erp_release_stocktake_settlement_on_payroll_line_delete();

create or replace function public.erp_release_stocktake_settlement_on_payroll_cancel()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status='draft' and new.status='cancelled' then
  update public.erp_stocktake_settlements set payroll_run_id=null,payroll_line_id=null,payroll_applied_at=null where payroll_run_id=new.id;
 end if;
 return new;
end $$;
drop trigger if exists trg_erp_release_stocktake_settlement_on_payroll_cancel on public.erp_payroll_runs;
create trigger trg_erp_release_stocktake_settlement_on_payroll_cancel after update of status on public.erp_payroll_runs
for each row execute function public.erp_release_stocktake_settlement_on_payroll_cancel();

revoke all on function public.erp_release_stocktake_settlement_on_payroll_line_delete() from public,anon,authenticated;
revoke all on function public.erp_release_stocktake_settlement_on_payroll_cancel() from public,anon,authenticated;