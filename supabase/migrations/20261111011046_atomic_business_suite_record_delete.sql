create or replace function public.erp_delete_business_suite_record(p_record_id uuid)
returns boolean
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
declare
  v_company_id uuid;
  v_details jsonb;
  v_status text;
  v_table text;
  v_operational_id uuid;
  v_deleted integer;
  v_allowed_tables text[] := array[
    'erp_asset_categories','erp_fixed_assets','erp_asset_depreciation_runs',
    'erp_asset_disposals','erp_asset_movements','erp_manufacturing_boms',
    'erp_manufacturing_work_centers','erp_production_orders',
    'erp_production_variances','erp_production_quality_checks',
    'erp_production_material_movements','erp_construction_projects',
    'erp_construction_material_requests','erp_construction_material_movements',
    'erp_construction_boq_lines','erp_construction_costs',
    'erp_construction_payment_certificates','erp_construction_site_reports',
    'erp_crm_leads','erp_service_sla_policies','erp_service_tickets',
    'erp_service_visits','erp_crm_activities'
  ];
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  select r.company_id, r.details, coalesce(r.status,'')
    into v_company_id, v_details, v_status
  from public.erp_business_suite_records r
  where r.id = p_record_id
  for update;
  if not found then
    raise exception 'Business suite record not found or not accessible' using errcode = 'P0002';
  end if;
  if not public.erp_user_has_company_role(v_company_id, array['owner','admin']::text[]) then
    raise exception 'Only company owners or administrators may delete business suite records' using errcode = '42501';
  end if;
  v_table := nullif(v_details->>'_operational_table','');
  v_operational_id := nullif(v_details->>'_operational_id','')::uuid;
  if v_table is not null and not (v_table = any(v_allowed_tables)) then
    raise exception 'Unsupported operational record type; deletion refused' using errcode = '22023';
  end if;
  if v_table = 'erp_construction_material_movements' then
    raise exception 'Inventory movements cannot be deleted; create a reversing movement instead' using errcode = '23514';
  elsif v_table = 'erp_asset_movements' and v_status = 'approved' then
    raise exception 'Approved asset movements cannot be deleted' using errcode = '23514';
  elsif v_table = 'erp_asset_disposals' and v_status = 'posted' then
    raise exception 'Posted asset disposals cannot be deleted' using errcode = '23514';
  elsif v_table = 'erp_asset_depreciation_runs' and v_status = any(array['approved','done','calculated','posted']) then
    raise exception 'Calculated or posted depreciation runs cannot be deleted' using errcode = '23514';
  elsif v_table = 'erp_construction_costs' and v_status = any(array['approved','posted']) then
    raise exception 'Approved or posted construction costs cannot be deleted' using errcode = '23514';
  elsif v_table = 'erp_construction_payment_certificates' and v_status = any(array['approved','paid']) then
    raise exception 'Approved or paid certificates cannot be deleted' using errcode = '23514';
  elsif v_table = 'erp_construction_material_requests' and v_status = any(array['approved','fulfilled']) then
    raise exception 'Approved or fulfilled material requests cannot be deleted' using errcode = '23514';
  end if;
  if v_table = 'erp_production_orders' and v_operational_id is not null then
    if exists (
      select 1 from public.erp_production_material_movements m
      where m.company_id = v_company_id and m.production_order_id = v_operational_id
    ) or exists (
      select 1 from public.erp_inventory_movements m
      where m.company_id = v_company_id and m.reference_type = 'production_order'
        and m.reference_id = v_operational_id
    ) then
      raise exception 'Production orders linked to inventory movements cannot be deleted' using errcode = '23514';
    end if;
  end if;
  if v_table is not null and v_operational_id is not null then
    execute format('delete from public.%I where id = $1 and company_id = $2', v_table)
      using v_operational_id, v_company_id;
    get diagnostics v_deleted = row_count;
    if v_deleted = 0 then
      raise exception 'Linked operational record is missing or not deletable' using errcode = 'P0002';
    end if;
  end if;
  delete from public.erp_business_suite_records
  where id = p_record_id and company_id = v_company_id;
  get diagnostics v_deleted = row_count;
  if v_deleted <> 1 then
    raise exception 'Business suite record could not be deleted' using errcode = 'P0002';
  end if;
  return true;
end;
$function$;
revoke all on function public.erp_delete_business_suite_record(uuid) from public;
revoke all on function public.erp_delete_business_suite_record(uuid) from anon;
grant execute on function public.erp_delete_business_suite_record(uuid) to authenticated;
