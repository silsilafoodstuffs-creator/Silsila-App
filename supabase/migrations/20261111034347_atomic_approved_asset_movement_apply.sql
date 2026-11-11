CREATE OR REPLACE FUNCTION public.erp_apply_approved_asset_movement()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_updated integer := 0;
begin
  if new.status is distinct from 'approved' then
    return new;
  end if;
  if tg_op='UPDATE' and old.status='approved' then
    return new;
  end if;

  update public.erp_fixed_assets
  set location=coalesce(nullif(btrim(new.to_location),''),location),
      custodian=coalesce(nullif(btrim(new.to_custodian),''),custodian),
      status=case
        when new.movement_type='maintenance_start' then 'under_maintenance'
        when new.movement_type='maintenance_end' and status='under_maintenance' then 'active'
        else status
      end,
      updated_at=now()
  where id=new.asset_id
    and company_id=new.company_id
    and status not in ('disposed','written_off');

  get diagnostics v_updated=row_count;
  if v_updated<>1 then
    raise exception 'الأصل غير موجود أو مستبعد ولا يمكن تطبيق حركة الاعتماد عليه' using errcode = '23514';
  end if;
  return new;
end;
$function$


revoke all on function public.erp_apply_approved_asset_movement() from public;
revoke all on function public.erp_apply_approved_asset_movement() from anon;
grant execute on function public.erp_apply_approved_asset_movement() to authenticated;

drop trigger if exists trg_erp_apply_approved_asset_movement on public.erp_asset_movements;
create trigger trg_erp_apply_approved_asset_movement after insert or update of status on public.erp_asset_movements for each row execute function public.erp_apply_approved_asset_movement();
