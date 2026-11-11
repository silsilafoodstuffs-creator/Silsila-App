CREATE OR REPLACE FUNCTION public.erp_recalculate_construction_project_actual_cost()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_company_id uuid;
  v_targets uuid[];
  v_project_id uuid;
  v_total numeric := 0;
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
      coalesce((
        select sum(c.amount)
        from public.erp_construction_costs c
        where c.company_id=v_company_id
          and c.project_id=v_project_id
          and c.status in ('approved','posted')
      ),0)
      +
      coalesce((
        select sum(
          m.quantity*m.unit_cost*
          case when m.movement_type='return' then -1 else 1 end
        )
        from public.erp_construction_material_movements m
        where m.company_id=v_company_id
          and m.project_id=v_project_id
      ),0)
    into v_total;

    update public.erp_construction_projects p
    set actual_cost=v_total,updated_at=now()
    where p.id=v_project_id and p.company_id=v_company_id;
    get diagnostics v_updated=row_count;
    if v_updated<>1 then
      raise exception 'تعذر تحديث إجمالي تكلفة المشروع ضمن نطاق الشركة' using errcode = '42501';
    end if;
  end loop;

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$function$


revoke all on function public.erp_recalculate_construction_project_actual_cost() from public;
revoke all on function public.erp_recalculate_construction_project_actual_cost() from anon;
grant execute on function public.erp_recalculate_construction_project_actual_cost() to authenticated;

drop trigger if exists trg_erp_construction_cost_project_total on public.erp_construction_costs;
create trigger trg_erp_construction_cost_project_total after insert or update or delete on public.erp_construction_costs for each row execute function public.erp_recalculate_construction_project_actual_cost();

drop trigger if exists trg_erp_construction_material_project_total on public.erp_construction_material_movements;
create trigger trg_erp_construction_material_project_total after insert or update or delete on public.erp_construction_material_movements for each row execute function public.erp_recalculate_construction_project_actual_cost();
