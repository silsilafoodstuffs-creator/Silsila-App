create or replace view public.erp_v_service_customer_satisfaction
with (security_invoker = true)
as
select
  t.company_id,
  count(*)::bigint as total_tickets,
  count(t.satisfaction_score)::bigint as rated_tickets,
  round(avg(t.satisfaction_score), 2) as average_satisfaction_score,
  percentile_cont(0.5) within group (order by t.satisfaction_score) as median_satisfaction_score,
  min(t.satisfaction_score) as minimum_satisfaction_score,
  max(t.satisfaction_score) as maximum_satisfaction_score,
  round(100.0 * count(t.satisfaction_score)::numeric / nullif(count(*)::numeric, 0), 2) as rating_coverage_percent,
  max(t.updated_at) as last_ticket_update
from public.erp_service_tickets t
group by t.company_id;

revoke all on public.erp_v_service_customer_satisfaction from anon, public;
grant select on public.erp_v_service_customer_satisfaction to authenticated;
