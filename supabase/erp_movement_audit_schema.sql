-- Silsila ERP movement audit table.
-- Review the deployed tenant model and add restrictive RLS policies before use.
-- RLS is enabled with no permissive policy, so clients remain denied by default.
-- For high-integrity audit, critical events should be written by trusted server workflows.

create table if not exists public.erp_movement_audit (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  area_key text not null,
  action_key text not null,
  entity_type text not null,
  entity_id uuid,
  reference_code text,
  description text,
  details jsonb not null default '{}'::jsonb,
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists erp_movement_audit_company_created_idx
  on public.erp_movement_audit(company_id, created_at desc);

create index if not exists erp_movement_audit_company_area_created_idx
  on public.erp_movement_audit(company_id, area_key, created_at desc);

alter table public.erp_movement_audit enable row level security;

comment on table public.erp_movement_audit is
  'Company-scoped audit trail. Add reviewed company-membership policies before production use.';
