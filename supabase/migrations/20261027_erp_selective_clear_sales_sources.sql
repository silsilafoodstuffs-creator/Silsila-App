-- Include dedicated sales invoice sources in the safe, company-scoped selective backup/clear allowlist.
begin;
do $$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.erp_prepare_selective_data_clear(uuid,text[])'::regprocedure);
  v_def := replace(
    v_def,
    '(''عروض الأصناف'',''erp_sales_campaigns''),(''عروض الأصناف'',''erp_sales_campaign_items''),(''الحملات التسويقية'',''erp_sales_campaign_items''),(''قواعد العروض'',''erp_sales_campaign_items''),',
    '(''عروض الأصناف'',''erp_sales_campaigns''),(''عروض الأصناف'',''erp_sales_campaign_items''),(''مجلات عروض العملاء'',''erp_sales_campaigns''),(''مجلات عروض العملاء'',''erp_sales_campaign_items''),(''عروض الترويج'',''erp_sales_campaigns''),(''عروض الترويج'',''erp_sales_campaign_items''),(''عروض الرواكد'',''erp_sales_campaigns''),(''عروض الرواكد'',''erp_sales_campaign_items''),(''نواقص العملاء'',''erp_customer_shortages''),(''الحملات التسويقية'',''erp_sales_campaign_items''),(''قواعد العروض'',''erp_sales_campaign_items''),'
  );
  if position('''نواقص العملاء'',''erp_customer_shortages''' in v_def) = 0 then
    raise exception 'Could not add customer shortages mapping to backup function';
  end if;
  execute v_def;
end $$;
commit;
