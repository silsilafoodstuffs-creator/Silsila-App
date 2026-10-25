create table if not exists public.erp_supplier_deferred_commissions (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 supplier_id uuid references public.erp_parties(id) on delete set null,
 supplier_name text not null default '',
 entry_date date not null default current_date,
 entry_type text not null default 'مؤجل',
 description text not null default '',
 base_amount numeric(14,2) not null default 0 check (base_amount >= 0),
 variance_percent numeric(8,5) not null default 0.025 check (variance_percent >= 0),
 commission_amount numeric(14,2) not null default 0 check (commission_amount >= 0),
 due_date date,
 status text not null default 'معلق' check (status in ('معلق','مستحق','تمت التسوية','ملغي')),
 notes text not null default '',
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists erp_supplier_deferred_commissions_company_date_idx
 on public.erp_supplier_deferred_commissions(company_id, entry_date desc);
alter table public.erp_supplier_deferred_commissions enable row level security;
drop policy if exists erp_supplier_deferred_commissions_member_read on public.erp_supplier_deferred_commissions;
create policy erp_supplier_deferred_commissions_member_read on public.erp_supplier_deferred_commissions
 for select to authenticated using (exists (
  select 1 from public.erp_company_members m where m.company_id=erp_supplier_deferred_commissions.company_id and m.user_id=auth.uid() and m.is_active=true
 ));
drop policy if exists erp_supplier_deferred_commissions_manager_write on public.erp_supplier_deferred_commissions;
create policy erp_supplier_deferred_commissions_manager_write on public.erp_supplier_deferred_commissions
 for all to authenticated using (exists (
  select 1 from public.erp_company_members m where m.company_id=erp_supplier_deferred_commissions.company_id and m.user_id=auth.uid() and m.is_active=true and lower(m.member_role) in ('owner','مالك','admin','ادمن','مدير النظام','مدير')
 )) with check (exists (
  select 1 from public.erp_company_members m where m.company_id=erp_supplier_deferred_commissions.company_id and m.user_id=auth.uid() and m.is_active=true and lower(m.member_role) in ('owner','مالك','admin','ادمن','مدير النظام','مدير')
 ));
