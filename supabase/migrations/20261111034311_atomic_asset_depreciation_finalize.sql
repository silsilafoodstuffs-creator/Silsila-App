CREATE OR REPLACE FUNCTION public.erp_finalize_asset_depreciation_run(p_company_id uuid, p_run_id uuid, p_post boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_total numeric;
  v_journal_entry_id uuid;
begin
  if auth.uid() is null then
    raise exception 'يلزم تسجيل الدخول' using errcode = '28000';
  end if;
  if p_company_id is null or p_run_id is null then
    raise exception 'الشركة وتشغيل الإهلاك مطلوبان' using errcode = '22023';
  end if;

  v_total:=public.erp_calculate_asset_depreciation(p_company_id,p_run_id);

  if coalesce(p_post,false) then
    v_journal_entry_id:=public.erp_post_asset_depreciation_run(p_company_id,p_run_id);
  end if;

  return jsonb_build_object(
    'total_amount',v_total,
    'journal_entry_id',v_journal_entry_id,
    'posted',coalesce(p_post,false)
  );
end;
$function$


revoke all on function public.erp_finalize_asset_depreciation_run(uuid,uuid,boolean) from public;
revoke all on function public.erp_finalize_asset_depreciation_run(uuid,uuid,boolean) from anon;
grant execute on function public.erp_finalize_asset_depreciation_run(uuid,uuid,boolean) to authenticated;
