-- Customer and supplier master-data fields and controlled classifications.
begin;

alter table public.erp_parties
  add column if not exists party_name_en text,
  add column if not exists country text not null default 'مصر',
  add column if not exists transaction_type text,
  add column if not exists sales_rep_employee_id uuid references public.erp_employees(id) on delete set null;

update public.erp_parties
set transaction_type = 'نقدي'
where party_kind = 'customer' and (transaction_type is null or btrim(transaction_type) = '');

alter table public.erp_parties
  drop constraint if exists erp_parties_transaction_type_check;
alter table public.erp_parties
  add constraint erp_parties_transaction_type_check
  check (transaction_type is null or transaction_type in ('نقدي','آجل','بيع مباشر'));

create index if not exists idx_erp_parties_company_kind_code
  on public.erp_parties(company_id, party_kind, party_code);
create index if not exists idx_erp_parties_sales_rep
  on public.erp_parties(company_id, sales_rep_employee_id)
  where sales_rep_employee_id is not null;

create table if not exists public.erp_party_classifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  party_kind text not null check (party_kind in ('customer','supplier')),
  name_ar text not null,
  name_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_party_classifications_company_kind_name unique(company_id,party_kind,name_ar),
  check (length(btrim(name_ar)) > 0)
);

alter table public.erp_party_classifications enable row level security;
drop policy if exists erp_party_classifications_company_access on public.erp_party_classifications;
create policy erp_party_classifications_company_access
  on public.erp_party_classifications
  for all to authenticated
  using (public.erp_user_can_access_company(company_id))
  with check (public.erp_user_can_access_company(company_id));

-- Seed common classifications for every existing company without overwriting user choices.
insert into public.erp_party_classifications(company_id,party_kind,name_ar,name_en)
select c.id, 'customer', v.name_ar, v.name_en
from public.erp_companies c
cross join (values
 ('ماركت','Market'),('سوبر ماركت','Supermarket'),('جملة','Wholesale'),('نصف جملة','Semi-wholesale'),
 ('بقالة','Grocery'),('مطعم','Restaurant'),('فندق','Hotel'),('مؤسسة / شركة','Organization / Company')
) as v(name_ar,name_en)
on conflict(company_id,party_kind,name_ar) do nothing;

insert into public.erp_party_classifications(company_id,party_kind,name_ar,name_en)
select c.id, 'supplier', v.name_ar, v.name_en
from public.erp_companies c
cross join (values
 ('مصنع','Manufacturer'),('موزع','Distributor'),('تاجر جملة','Wholesaler'),('مستورد','Importer'),('منتج','Producer'),('خدمات','Services')
) as v(name_ar,name_en)
on conflict(company_id,party_kind,name_ar) do nothing;

commit;
