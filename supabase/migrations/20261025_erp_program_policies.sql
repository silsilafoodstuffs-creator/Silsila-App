-- Company-scoped ERP program policies.
create table if not exists public.erp_program_policies (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 policy_key text not null, category text not null, name_ar text not null, name_en text not null,
 is_enabled boolean not null default false, apply_to_all boolean not null default true,
 user_ids jsonb not null default '[]'::jsonb, policy_value text not null default '',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,policy_key)
);
alter table public.erp_program_policies enable row level security;
drop policy if exists erp_program_policies_member_read on public.erp_program_policies;
create policy erp_program_policies_member_read on public.erp_program_policies for select to authenticated using (exists (select 1 from public.erp_company_members m where m.company_id=erp_program_policies.company_id and m.user_id=auth.uid() and m.is_active=true));
drop policy if exists erp_program_policies_manager_write on public.erp_program_policies;
create policy erp_program_policies_manager_write on public.erp_program_policies for all to authenticated using (exists (select 1 from public.erp_company_members m where m.company_id=erp_program_policies.company_id and m.user_id=auth.uid() and m.is_active=true and lower(m.member_role) in ('owner','مالك','admin','ادمن','مدير النظام','مدير'))) with check (exists (select 1 from public.erp_company_members m where m.company_id=erp_program_policies.company_id and m.user_id=auth.uid() and m.is_active=true and lower(m.member_role) in ('owner','مالك','admin','ادمن','مدير النظام','مدير')));
