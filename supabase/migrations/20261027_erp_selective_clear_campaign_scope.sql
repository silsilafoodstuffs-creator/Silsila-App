-- Preserve screen-level isolation when selectively backing up and clearing sales campaigns.
begin;
do $$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.erp_prepare_selective_data_clear(uuid,text[])'::regprocedure);
  v_def := replace(v_def, '  v_voucher_types text[];', E'  v_voucher_types text[];\n  v_campaign_types text[];');
  v_old := E'  if coalesce(array_length(v_pages, 1), 0) = 0 then\n    raise exception ''حدد شاشة واحدة على الأقل.'';\n  end if;';
  v_new := v_old || E'\n\n  select coalesce(array_agg(distinct case p when ''مجلات عروض العملاء'' then ''customer_magazine'' when ''عروض الترويج'' then ''promotion'' when ''عروض الرواكد'' then ''slow_moving'' end) filter (where p in (''مجلات عروض العملاء'',''عروض الترويج'',''عروض الرواكد'')), ''{}''::text[]) into v_campaign_types from unnest(v_pages) p;\n  if ''عروض الأصناف'' = any(v_pages) or ''الحملات التسويقية'' = any(v_pages) then v_campaign_types := array[''customer_magazine'',''promotion'',''slow_moving'']::text[]; end if;';
  v_def := replace(v_def, v_old, v_new);
  v_old := E'    elsif v_table = ''erp_sales_documents'' then';
  v_new := E'    elsif v_table = ''erp_sales_campaigns'' and cardinality(v_campaign_types)>0 then\n      select coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb) into v_rows from public.erp_sales_campaigns t where t.company_id=p_company_id and t.campaign_type=any(v_campaign_types);\n    elsif v_table = ''erp_sales_campaign_items'' and cardinality(v_campaign_types)>0 then\n      select coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb) into v_rows from public.erp_sales_campaign_items t join public.erp_sales_campaigns c on c.id=t.campaign_id where t.company_id=p_company_id and c.company_id=p_company_id and c.campaign_type=any(v_campaign_types);\n' || v_old;
  v_def := replace(v_def, v_old, v_new);
  execute v_def;

  v_def := pg_get_functiondef('public.erp_complete_selective_data_clear(uuid,text)'::regprocedure);
  v_def := replace(v_def, '  v_voucher_types text[];', E'  v_voucher_types text[];\n  v_campaign_types text[];');
  v_old := '  v_pages := v_backup.selected_pages;';
  v_new := v_old || E'\n  select coalesce(array_agg(distinct case p when ''مجلات عروض العملاء'' then ''customer_magazine'' when ''عروض الترويج'' then ''promotion'' when ''عروض الرواكد'' then ''slow_moving'' end) filter (where p in (''مجلات عروض العملاء'',''عروض الترويج'',''عروض الرواكد'')), ''{}''::text[]) into v_campaign_types from unnest(v_pages) p;\n  if ''عروض الأصناف'' = any(v_pages) or ''الحملات التسويقية'' = any(v_pages) then v_campaign_types := array[''customer_magazine'',''promotion'',''slow_moving'']::text[]; end if;';
  v_def := replace(v_def, v_old, v_new);
  v_old := E'    elsif v_table = ''erp_sales_documents'' then';
  v_new := E'    elsif v_table = ''erp_sales_campaign_items'' and cardinality(v_campaign_types)>0 then\n      delete from public.erp_sales_campaign_items t using public.erp_sales_campaigns c where t.campaign_id=c.id and t.company_id=p_company_id and c.company_id=p_company_id and c.campaign_type=any(v_campaign_types);\n      get diagnostics v_deleted = row_count;\n    elsif v_table = ''erp_sales_campaigns'' and cardinality(v_campaign_types)>0 then\n      delete from public.erp_sales_campaigns where company_id=p_company_id and campaign_type=any(v_campaign_types);\n      get diagnostics v_deleted = row_count;\n' || v_old;
  v_def := replace(v_def, v_old, v_new);
  if position('v_campaign_types text[];' in v_def) = 0 then raise exception 'Campaign scope declaration missing'; end if;
  execute v_def;
end $$;
commit;
