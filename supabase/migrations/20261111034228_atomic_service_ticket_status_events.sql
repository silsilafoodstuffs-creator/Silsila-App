CREATE OR REPLACE FUNCTION public.erp_log_service_ticket_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  if new.status is distinct from old.status then
    insert into public.erp_service_ticket_events(
      company_id,ticket_id,event_type,from_status,to_status,note,performed_by
    )
    values(
      new.company_id,new.id,'status_change',old.status,new.status,
      'تغيير الحالة من شاشة سلسلة',(select auth.uid())
    );
  end if;
  return new;
end;
$function$


revoke all on function public.erp_log_service_ticket_status_change() from public;
revoke all on function public.erp_log_service_ticket_status_change() from anon;
grant execute on function public.erp_log_service_ticket_status_change() to authenticated;

drop trigger if exists trg_erp_service_ticket_status_event on public.erp_service_tickets;
create trigger trg_erp_service_ticket_status_event
after update of status on public.erp_service_tickets
for each row
when (old.status is distinct from new.status)
execute function public.erp_log_service_ticket_status_change();
