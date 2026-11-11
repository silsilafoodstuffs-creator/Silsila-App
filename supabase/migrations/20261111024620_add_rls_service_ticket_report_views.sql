create or replace view public.erp_v_service_open_tickets
with (security_invoker = true)
as
select
  t.id, t.company_id, t.ticket_code, t.subject, t.description, t.party_id, t.lead_id,
  t.channel, t.category, t.priority, t.status, t.team_name, t.assigned_to, t.sla_policy_id,
  t.first_response_due_at, t.resolution_due_at, t.first_responded_at, t.resolved_at, t.closed_at,
  t.satisfaction_score, t.resolution, t.created_by, t.created_at, t.updated_at, t.escalation_due_at,
  round((extract(epoch from (now() - t.created_at)) / 60.0)::numeric, 2) as age_minutes,
  (t.first_response_due_at is not null and t.first_responded_at is null and now() > t.first_response_due_at) as first_response_overdue,
  (t.resolution_due_at is not null and t.resolved_at is null and t.closed_at is null and now() > t.resolution_due_at) as resolution_overdue
from public.erp_service_tickets t
where t.status not in ('closed','resolved','cancelled');

create or replace view public.erp_v_service_ticket_response_metrics
with (security_invoker = true)
as
select
  t.id, t.company_id, t.ticket_code, t.subject, t.priority, t.status, t.team_name, t.assigned_to,
  t.sla_policy_id, t.created_at, t.first_responded_at, t.first_response_due_at,
  coalesce(p.business_hours_only, false) as business_hours_only,
  case when t.first_responded_at is not null
    then round((extract(epoch from (t.first_responded_at - t.created_at)) / 60.0)::numeric, 2)
    else null end as calendar_response_minutes,
  case
    when p.business_hours_only then null
    when t.first_responded_at is not null and t.first_response_due_at is not null then (t.first_responded_at <= t.first_response_due_at)
    when t.first_responded_at is null and t.first_response_due_at is not null then (now() <= t.first_response_due_at)
    else null
  end as response_sla_met,
  case
    when p.business_hours_only then 'business_calendar_required'
    when t.first_response_due_at is null then 'no_response_sla'
    when t.first_responded_at is not null and t.first_responded_at <= t.first_response_due_at then 'met'
    when t.first_responded_at is not null then 'breached'
    when now() <= t.first_response_due_at then 'pending'
    else 'breached'
  end as response_sla_status
from public.erp_service_tickets t
left join public.erp_service_sla_policies p on p.id = t.sla_policy_id and p.company_id = t.company_id;

revoke all on public.erp_v_service_open_tickets from anon, public;
revoke all on public.erp_v_service_ticket_response_metrics from anon, public;
grant select on public.erp_v_service_open_tickets to authenticated;
grant select on public.erp_v_service_ticket_response_metrics to authenticated;
