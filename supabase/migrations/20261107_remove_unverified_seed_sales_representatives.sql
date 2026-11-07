-- Remove the known starter sales-representative rows created with the retired
-- demo goals/commissions setup. They have no employee, customer, sales, or
-- commission relationships and contain only default zero target/commission values.
delete from public.erp_sales_representatives r
where (r.rep_code,r.rep_name) in (
  ('REP-0001','مصطفى سعيد'),
  ('REP-0003','زهراء عبد العاطي'),
  ('REP-0004','علي الجمل'),
  ('REP-0005','هدي محمد'),
  ('REP-0006','عبير عبد العاطي'),
  ('REP-0007','دنيا علي'),
  ('REP-0010','اسراء علي'),
  ('REP-0011','أحمد عطية')
)
and r.employee_id is null
and coalesce(r.monthly_sales_target,0)=0
and coalesce(r.monthly_collection_target,0)=0
and coalesce(r.default_commission_rate,0)=0
and not exists (select 1 from public.erp_commission_runs x where x.representative_id=r.id)
and not exists (select 1 from public.erp_parties x where x.sales_rep_id=r.id)
and not exists (select 1 from public.erp_sales_documents x where x.sales_rep_id=r.id);
