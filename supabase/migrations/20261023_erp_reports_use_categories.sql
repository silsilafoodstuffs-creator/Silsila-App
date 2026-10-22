-- Move ERP reporting queries from the legacy group table to canonical item categories.
-- Rewrites the installed function definitions while preserving their signatures, grants and security attributes.
do $$
declare v_def text;
begin
 v_def := pg_get_functiondef('public.erp_get_executive_metrics(uuid,date,date)'::regprocedure);
 v_def := replace(v_def,'public.erp_item_groups g on g.id=i.group_id and g.company_id=p_company_id','public.erp_item_categories g on g.id=i.category_id and g.company_id=p_company_id');
 v_def := replace(v_def,'i.group_id','i.category_id');
 v_def := replace(v_def,'g.group_name','g.category_name');
 execute v_def;

 v_def := pg_get_functiondef('public.erp_run_movement_audit(uuid,date,date,text)'::regprocedure);
 v_def := replace(v_def,'erp_item_groups','erp_item_categories');
 v_def := replace(v_def,'group_code','category_code');
 v_def := replace(v_def,'group_name_en','category_name_en');
 v_def := replace(v_def,'group_name','category_name');
 v_def := replace(v_def,'group_id','category_id');
 v_def := replace(v_def,'ITEM_GROUP','ITEM_CATEGORY');
 v_def := replace(v_def,'''groups''','''categories''');
 v_def := replace(v_def,'مجموعة','فئة');
 execute v_def;
end $$;
