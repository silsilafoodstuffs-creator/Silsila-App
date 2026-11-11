CREATE OR REPLACE FUNCTION public.erp_recalculate_construction_project_progress()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_company_id uuid;
  v_targets uuid[];
  v_project_id uuid;
  v_budget numeric := 0;
  v_executed numeric := 0;
  v_progress numeric := 0;
  v_updated integer := 0;
begin
  if tg_op='DELETE' then
    v_company_id:=old.company_id;
    v_targets:=array[old.project_id];
  elsif tg_op='UPDATE' then
    v_company_id:=new.company_id;
    v_targets:=array[old.project_id,new.project_id];
  else
    v_company_id:=new.company_id;
    v_targets:=array[new.project_id];
  end if;

  for v_project_id in
    select distinct x.project_id
    from unnest(v_targets) as x(project_id)
    where x.project_id is not null
    order by x.project_id
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_company_id::text||':'||v_project_id::text,0)
    );

    select
      coalesce(sum(b.planned_quantity*b.unit_rate),0),
      coalesce(sum(b.executed_quantity*b.unit_rate),0)
    into v_budget,v_executed
    from public.erp_construction_boq_lines b
    where b.company_id=v_company_id and b.project_id=v_project_id;

    v_progress:=case
      when v_budget<=0 then 0
      else least(greatest(v_executed/v_budget*100,0),100)
    end;

    update public.erp_construction_projects p
    set progress_percent=v_progress,updated_at=now()
    where p.id=v_project_id and p.company_id=v_company_id;
    get diagnostics v_updated=row_count;
    if v_updated<>1 then
      raise exception 'تعذر تحديث نسبة إنجاز المشروع ضمن نطاق الشركة' using errcode = '42501';
    end if;
  end loop;

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$function$


revoke all on function public.erp_recalculate_construction_project_progress() from public;
revoke all on function public.erp_recalculate_construction_project_progress() from anon;
grant execute on function public.erp_recalculate_construction_project_progress() to authenticated;

drop trigger if exists trg_erp_construction_boq_project_progress on public.erp_construction_boq_lines;
create trigger trg_erp_construction_boq_project_progress after insert or update or delete on public.erp_construction_boq_lines for each row execute function public.erp_recalculate_construction_project_progress();
