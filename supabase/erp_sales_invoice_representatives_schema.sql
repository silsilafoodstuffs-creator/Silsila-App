-- Repair the sales invoice schema used by the Silsila ERP Flutter web screen.
-- Safe to run repeatedly.
alter table public.erp_sales_documents
  add column if not exists sales_rep_id uuid,
  add column if not exists is_tax_invoice boolean not null default false;

create table if not exists public.erp_sales_representatives (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  rep_code text not null,
  rep_name text not null,
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_sales_representatives_company_code_unique unique(company_id, rep_code),
  constraint erp_sales_representatives_company_name_unique unique(company_id, rep_name)
);

create index if not exists erp_sales_representatives_company_active_idx
  on public.erp_sales_representatives(company_id, is_active, rep_name);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'erp_sales_documents_sales_rep_id_fkey'
      and conrelid = 'public.erp_sales_documents'::regclass
  ) then
    alter table public.erp_sales_documents
      add constraint erp_sales_documents_sales_rep_id_fkey
      foreign key (sales_rep_id) references public.erp_sales_representatives(id) on delete set null;
  end if;
end $$;

alter table public.erp_sales_representatives enable row level security;

drop policy if exists erp_sales_representatives_select_member on public.erp_sales_representatives;
create policy erp_sales_representatives_select_member
  on public.erp_sales_representatives for select to authenticated
  using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_sales_representatives_insert_operator on public.erp_sales_representatives;
create policy erp_sales_representatives_insert_operator
  on public.erp_sales_representatives for insert to authenticated
  with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]));

drop policy if exists erp_sales_representatives_update_operator on public.erp_sales_representatives;
create policy erp_sales_representatives_update_operator
  on public.erp_sales_representatives for update to authenticated
  using (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]))
  with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]));

drop policy if exists erp_sales_representatives_delete_admin on public.erp_sales_representatives;
create policy erp_sales_representatives_delete_admin
  on public.erp_sales_representatives for delete to authenticated
  using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

grant select, insert, update, delete on public.erp_sales_representatives to authenticated;
