create table if not exists public.erp_payment_methods (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  payment_method_code text not null,
  name_ar text not null,
  name_en text not null default '',
  method_type text not null check (method_type in ('cash','bank_transfer','cheque','card','e_wallet','credit')),
  cashbox_id uuid references public.erp_cashboxes(id) on delete set null,
  allow_receipts boolean not null default true,
  allow_payments boolean not null default true,
  requires_reference boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, payment_method_code),
  unique(company_id, name_ar)
);

create index if not exists erp_payment_methods_company_active_idx
  on public.erp_payment_methods(company_id, is_active, payment_method_code);

create or replace function public.erp_assign_payment_method_code()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_next integer;
begin
  if new.payment_method_code is null or btrim(new.payment_method_code) = '' then
    perform pg_advisory_xact_lock(hashtextextended(new.company_id::text, 0));
    select coalesce(max(substring(payment_method_code from 4)::integer), 0) + 1
      into v_next
    from public.erp_payment_methods
    where company_id = new.company_id
      and payment_method_code ~ '^PAY[0-9]{4,}$';
    new.payment_method_code := 'PAY' || lpad(v_next::text, 4, '0');
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists erp_payment_methods_code_trigger on public.erp_payment_methods;
create trigger erp_payment_methods_code_trigger
before insert or update on public.erp_payment_methods
for each row execute function public.erp_assign_payment_method_code();

alter table public.erp_payment_methods enable row level security;

drop policy if exists erp_payment_methods_select_member on public.erp_payment_methods;
create policy erp_payment_methods_select_member on public.erp_payment_methods
for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_payment_methods_insert_manager on public.erp_payment_methods;
create policy erp_payment_methods_insert_manager on public.erp_payment_methods
for insert to authenticated
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager']::text[]));

drop policy if exists erp_payment_methods_update_manager on public.erp_payment_methods;
create policy erp_payment_methods_update_manager on public.erp_payment_methods
for update to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant','manager']::text[]));

grant select, insert, update on public.erp_payment_methods to authenticated;

insert into public.erp_payment_methods(company_id, payment_method_code, name_ar, name_en, method_type, requires_reference)
select c.id, '', v.name_ar, v.name_en, v.method_type, v.requires_reference
from public.erp_companies c
cross join (values
  ('نقدي', 'Cash', 'cash', false),
  ('تحويل بنكي', 'Bank Transfer', 'bank_transfer', true),
  ('شيك', 'Cheque', 'cheque', true),
  ('بطاقة بنكية', 'Bank Card', 'card', true),
  ('محفظة إلكترونية', 'E-Wallet', 'e_wallet', true),
  ('آجل', 'Credit', 'credit', false)
) as v(name_ar, name_en, method_type, requires_reference)
on conflict (company_id, name_ar) do nothing;
