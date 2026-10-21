-- Separate read and write policies to avoid overlapping permissive SELECT rules.
drop policy if exists erp_customer_goals_write_sales on public.erp_customer_monthly_goals;
drop policy if exists erp_customer_goals_insert_sales on public.erp_customer_monthly_goals;
create policy erp_customer_goals_insert_sales on public.erp_customer_monthly_goals for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_customer_goals_update_sales on public.erp_customer_monthly_goals;
create policy erp_customer_goals_update_sales on public.erp_customer_monthly_goals for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_customer_goals_delete_sales on public.erp_customer_monthly_goals;
create policy erp_customer_goals_delete_sales on public.erp_customer_monthly_goals for delete to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));

drop policy if exists erp_commission_plans_write_manager on public.erp_commission_plans;
drop policy if exists erp_commission_plans_insert_manager on public.erp_commission_plans;
create policy erp_commission_plans_insert_manager on public.erp_commission_plans for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_commission_plans_update_manager on public.erp_commission_plans;
create policy erp_commission_plans_update_manager on public.erp_commission_plans for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','manager','accountant']::text[]));
drop policy if exists erp_commission_plans_delete_manager on public.erp_commission_plans;
create policy erp_commission_plans_delete_manager on public.erp_commission_plans for delete to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));

drop policy if exists erp_commission_tiers_write_manager on public.erp_commission_tiers;
drop policy if exists erp_commission_tiers_insert_manager on public.erp_commission_tiers;
create policy erp_commission_tiers_insert_manager on public.erp_commission_tiers for insert to authenticated
with check (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','manager','accountant']::text[])));
drop policy if exists erp_commission_tiers_update_manager on public.erp_commission_tiers;
create policy erp_commission_tiers_update_manager on public.erp_commission_tiers for update to authenticated
using (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','manager','accountant']::text[])))
with check (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','manager','accountant']::text[])));
drop policy if exists erp_commission_tiers_delete_manager on public.erp_commission_tiers;
create policy erp_commission_tiers_delete_manager on public.erp_commission_tiers for delete to authenticated
using (exists (select 1 from public.erp_commission_plans p where p.id=plan_id and public.erp_user_has_company_role(p.company_id,array['owner','admin','accountant']::text[])));

drop policy if exists erp_commission_runs_write_manager on public.erp_commission_runs;
drop policy if exists erp_commission_runs_insert_manager on public.erp_commission_runs;
create policy erp_commission_runs_insert_manager on public.erp_commission_runs for insert to authenticated
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
drop policy if exists erp_commission_runs_update_manager on public.erp_commission_runs;
create policy erp_commission_runs_update_manager on public.erp_commission_runs for update to authenticated
using (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
drop policy if exists erp_commission_runs_delete_manager on public.erp_commission_runs;
create policy erp_commission_runs_delete_manager on public.erp_commission_runs for delete to authenticated
using (status in ('draft','cancelled') and public.erp_user_has_company_role(company_id,array['owner','admin','accountant']::text[]));
