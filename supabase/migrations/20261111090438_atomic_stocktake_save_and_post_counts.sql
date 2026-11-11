CREATE OR REPLACE FUNCTION public.erp_post_physical_stocktake_with_counts(p_stocktake_id uuid, p_counts jsonb, p_target_type text DEFAULT NULL::text, p_target_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_result jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'يلزم تسجيل الدخول' using errcode='28000';
  end if;
  perform public.erp_save_physical_stocktake_counts(p_stocktake_id,p_counts);
  v_result:=public.erp_post_physical_stocktake(
    p_stocktake_id,p_target_type,p_target_id
  );
  return v_result;
end;
$function$
;

revoke all on function public.erp_post_physical_stocktake_with_counts(uuid,jsonb,text,uuid) from public;
revoke all on function public.erp_post_physical_stocktake_with_counts(uuid,jsonb,text,uuid) from anon;
grant execute on function public.erp_post_physical_stocktake_with_counts(uuid,jsonb,text,uuid) to authenticated;
