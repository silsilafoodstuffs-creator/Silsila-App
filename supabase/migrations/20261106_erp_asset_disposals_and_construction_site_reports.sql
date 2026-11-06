alter table public.erp_construction_projects
 add column if not exists budget_amount numeric(18,3) not null default 0 check(budget_amount>=0),
 add column if not exists actual_cost numeric(18,3) not null default 0 check(actual_cost>=0),
 add column if not exists progress_percent numeric(8,4) not null default 0 check(progress_percent between 0 and 100);

create table if not exists public.erp_asset_disposals (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 asset_id uuid not null, disposal_code text not null, disposal_date date not null,
 disposal_method text not null check(disposal_method in ('sale','scrap','write_off','donation')),
 reason text, buyer text, book_value numeric(18,3) not null check(book_value>=0),
 proceeds numeric(18,3) not null default 0 check(proceeds>=0), gain_loss numeric(18,3) generated always as (proceeds-book_value) stored,
 status text not null default 'draft' check(status in ('draft','approved','posted','cancelled')),
 journal_entry_id uuid references public.erp_journal_entries(id), created_by uuid default auth.uid(), created_at timestamptz not null default now(),
 unique(company_id,disposal_code), foreign key(asset_id,company_id) references public.erp_fixed_assets(id,company_id));
create table if not exists public.erp_construction_site_reports (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 project_id uuid not null, report_code text not null, report_date date not null, engineer text, weather text,
 labor_count integer not null default 0 check(labor_count>=0), equipment text, materials text, work_done text, issues text, safety text,
 status text not null default 'draft' check(status in ('draft','submitted','approved','rejected')),
 created_by uuid default auth.uid(), created_at timestamptz not null default now(),
 unique(company_id,report_code), foreign key(project_id,company_id) references public.erp_construction_projects(id,company_id));
create index if not exists erp_asset_disposals_asset_date_idx on public.erp_asset_disposals(company_id,asset_id,disposal_date desc);
create index if not exists erp_site_reports_project_date_idx on public.erp_construction_site_reports(company_id,project_id,report_date desc);
do $$
declare t text;
begin
 foreach t in array array['erp_asset_disposals','erp_construction_site_reports'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('grant select,insert,update,delete on public.%I to authenticated',t);
  execute format('create policy %I on public.%I for select to authenticated using (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'',''manager'']) or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = (select auth.uid())))',t||'_select',t,t);
  execute format('create policy %I on public.%I for insert to authenticated with check (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'',''manager'']) or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = (select auth.uid())))',t||'_insert',t,t);
  execute format('create policy %I on public.%I for update to authenticated using (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'',''manager'']) or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = (select auth.uid()))) with check (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'',''manager'']) or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = (select auth.uid())))',t||'_update',t,t,t);
  execute format('create policy %I on public.%I for delete to authenticated using (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'']))',t||'_delete',t);
 end loop;
end $$;
