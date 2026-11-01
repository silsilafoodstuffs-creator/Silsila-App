do $$
declare v_def text;
begin
 v_def:=pg_get_functiondef('public.erp_post_physical_stocktake(uuid,text,uuid)'::regprocedure);
 v_def:=replace(v_def,'v_doc.source<>''stocktake''','v_doc.source not in (''stocktake'',''manual'')');
 if position('v_doc.source not in (''stocktake'',''manual'')' in v_def)=0 then raise exception 'Could not extend stocktake posting source guard'; end if;
 execute v_def;
 v_def:=pg_get_functiondef('public.erp_save_physical_stocktake_counts(uuid,jsonb)'::regprocedure);
 v_def:=replace(v_def,'v_doc.source<>''stocktake''','v_doc.source not in (''stocktake'',''manual'')');
 if position('v_doc.source not in (''stocktake'',''manual'')' in v_def)=0 then raise exception 'Could not extend stocktake save source guard'; end if;
 execute v_def;
end $$;

drop function if exists public.erp_create_manual_stock_adjustment(uuid,uuid,text);
