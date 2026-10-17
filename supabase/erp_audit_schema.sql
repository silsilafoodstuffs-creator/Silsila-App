-- Silsila ERP audit trail and journal approval requests.
-- Apply only after reviewing the target Supabase project and its company-membership model.
-- Requires supabase/erp_schema.sql to have created erp_companies and erp_journal_entries.
-- RLS is enabled without permissive policies by design. Add reviewed company-membership
-- policies before use. Approval requests do not post, edit, or reverse accounting entries.

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

create table if not exists public.erp_journal_approval_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  journal_id uuid not null references public.erp_journal_entries(id) on delete restrict,
  request_type text not null
    check (request_type in ('submit', 'approve', 'return', 'reverse_request')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'returned', 'rejected', 'requested')),
  note text,
  reviewer_note text,
  requested_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists erp_journal_approval_company_status_idx
  on public.erp_journal_approval_requests(company_id, status, created_at desc);
create index if not exists erp_journal_approval_journal_idx
  on public.erp_journal_approval_requests(company_id, journal_id, created_at desc);

alter table public.erp_movement_audit enable row level security;
alter table public.erp_journal_approval_requests enable row level security;

comment on table public.erp_movement_audit is
  'Company-scoped ERP activity audit. For tamper resistance, critical events must be written by trusted server-side workflows.';
comment on table public.erp_journal_approval_requests is
  'Approval workflow requests only. Approval does not itself post or reverse an accounting journal.';
