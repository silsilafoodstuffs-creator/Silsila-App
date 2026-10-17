-- Silsila ERP external API integration foundation
-- Apply only after erp_schema.sql has been applied and company access policies are designed.
-- IMPORTANT: This file intentionally does not create public/anonymous access policies.
-- Never store raw API secrets. Store only a cryptographic hash generated server-side.
-- Keep privileged credentials in server-side environment variables / secret manager.

create extension if not exists pgcrypto;

create table if not exists public.erp_api_clients (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  client_name text not null,
  client_code text not null,
  description text,
  key_prefix text not null,
  secret_hash text not null,
  scopes text[] not null default array[]::text[],
  allowed_ips inet[] not null default array[]::inet[],
  rate_limit_per_minute integer not null default 60 check (rate_limit_per_minute between 1 and 10000),
  is_active boolean not null default true,
  expires_at timestamptz,
  last_used_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, client_code),
  unique (key_prefix)
);

create table if not exists public.erp_api_request_logs (
  id bigint generated always as identity primary key,
  company_id uuid references public.erp_companies(id) on delete restrict,
  api_client_id uuid references public.erp_api_clients(id) on delete set null,
  request_id text not null,
  http_method text not null,
  route text not null,
  response_status integer not null,
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  source_ip inet,
  user_agent text,
  error_code text,
  created_at timestamptz not null default now()
);

create index if not exists idx_erp_api_clients_company_active
  on public.erp_api_clients(company_id, is_active);

create index if not exists idx_erp_api_logs_company_created
  on public.erp_api_request_logs(company_id, created_at desc);

create index if not exists idx_erp_api_logs_client_created
  on public.erp_api_request_logs(api_client_id, created_at desc);

alter table public.erp_api_clients enable row level security;
alter table public.erp_api_request_logs enable row level security;

-- Access policies are deliberately omitted until authenticated company membership,
-- role permissions, and server-side API authentication are implemented.
-- Do not expose these tables directly to anon/authenticated clients.
-- Create/revoke API credentials only through a trusted server-side endpoint.
-- A raw API secret must be shown once at creation time and never logged.
