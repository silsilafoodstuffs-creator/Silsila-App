create or replace view public.erp_v_service_response_rate_summary
with (security_invoker = true)
as
select
  t.company_id,
  count(*)::bigint as total_tickets,
  count(*) filter (where t.first_responded_at is not null)::bigint as responded_tickets,
  round(
    100.0 * count(*) filter (where t.first_responded_at is not null)
    / nullif(count(*), 0), 2
  ) as response_coverage_percent,
  count(*) filter (
    where coalesce(p.business_hours_only, false) = false
      and t.first_response_due_at is not null
  )::bigint as sla_evaluable_tickets,
  count(*) filter (
    where coalesce(p.business_hours_only, false) = false
      and t.first_response_due_at is not null
      and t.first_responded_at is not null
      and t.first_responded_at <= t.first_response_due_at
  )::bigint as sla_met_tickets,
  round(
    100.0 * count(*) filter (
      where coalesce(p.business_hours_only, false) = false
        and t.first_response_due_at is not null
        and t.first_responded_at is not null
        and t.first_responded_at <= t.first_response_due_at
    )
    / nullif(count(*) filter (
      where coalesce(p.business_hours_only, false) = false
        and t.first_response_due_at is not null
    ), 0), 2
  ) as sla_met_percent,
  round(avg(extract(epoch from (t.first_responded_at - t.created_at)) / 60.0)
    filter (where t.first_responded_at is not null), 2) as average_calendar_response_minutes,
  max(t.updated_at) as last_ticket_update
from public.erp_service_tickets t
left join public.erp_service_sla_policies p
  on p.id = t.sla_policy_id
 and p.company_id = t.company_id
group by t.company_id;

revoke all on public.erp_v_service_response_rate_summary from public, anon;
grant select on public.erp_v_service_response_rate_summary to authenticated;
