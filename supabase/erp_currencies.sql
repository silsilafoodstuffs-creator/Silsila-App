-- Company-scoped currency master data used by lib/erp/screens/erp_currencies_screen.dart.
-- Safe to re-run: policies/triggers are replaced and default rows use ON CONFLICT DO NOTHING.
create table if not exists public.erp_currencies (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  currency_code text not null check (currency_code ~ '^[A-Z0-9]{2,12}$'),
  currency_name_ar text not null check (length(btrim(currency_name_ar)) > 0),
  currency_symbol text not null check (length(btrim(currency_symbol)) > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, currency_code)
);

create index if not exists erp_currencies_company_active_idx
  on public.erp_currencies(company_id, is_active, currency_code);

alter table public.erp_currencies enable row level security;

drop policy if exists erp_currencies_select_member on public.erp_currencies;
create policy erp_currencies_select_member
  on public.erp_currencies for select to authenticated
  using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_currencies_insert_finance on public.erp_currencies;
create policy erp_currencies_insert_finance
  on public.erp_currencies for insert to authenticated
  with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));

drop policy if exists erp_currencies_update_finance on public.erp_currencies;
create policy erp_currencies_update_finance
  on public.erp_currencies for update to authenticated
  using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]))
  with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));

drop policy if exists erp_currencies_delete_admin on public.erp_currencies;
create policy erp_currencies_delete_admin
  on public.erp_currencies for delete to authenticated
  using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

grant select, insert, update, delete on public.erp_currencies to authenticated;

drop trigger if exists erp_currencies_set_updated_at on public.erp_currencies;
create trigger erp_currencies_set_updated_at
  before update on public.erp_currencies
  for each row execute function public.erp_set_updated_at();

insert into public.erp_currencies(company_id, currency_code, currency_name_ar, currency_symbol)
select c.id, v.currency_code, v.currency_name_ar, v.currency_symbol
from public.erp_companies c
cross join (values
  ('EGP','جنيه مصري','EGP'),
  ('USD','دولار أمريكي','USD'),
  ('SAR','ريال سعودي','SAR'),
  ('AED','درهم إماراتي','AED'),
  ('KWD','دينار كويتي','KWD'),
  ('EUR','يورو','EUR'),
  ('GBP','جنيه إسترليني','GBP')
) as v(currency_code, currency_name_ar, currency_symbol)
on conflict (company_id, currency_code) do nothing;
