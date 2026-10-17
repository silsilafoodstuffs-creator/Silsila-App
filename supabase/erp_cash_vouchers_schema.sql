-- Silsila ERP cash receipts, cash payments, and inter-cashbox transfers.
-- Apply after erp_schema.sql. Add membership policies before client access.

create table if not exists public.erp_cash_vouchers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  voucher_number text not null,
  voucher_date date not null default current_date,
  voucher_type text not null check (voucher_type in ('receipt','payment','transfer')),
  source_cashbox_id uuid not null references public.erp_cashboxes(id) on delete restrict,
  destination_cashbox_id uuid references public.erp_cashboxes(id) on delete restrict,
  counter_account_id uuid references public.erp_accounts(id) on delete restrict,
  party_id uuid references public.erp_parties(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  description text not null,
  status text not null default 'draft' check (status in ('draft','posted','cancelled')),
  journal_entry_id uuid references public.erp_journal_entries(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  posted_by uuid references auth.users(id) on delete set null,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, voucher_number),
  check (
    (voucher_type = 'transfer' and destination_cashbox_id is not null
      and destination_cashbox_id <> source_cashbox_id and counter_account_id is null and party_id is null)
    or
    (voucher_type in ('receipt','payment') and destination_cashbox_id is null and counter_account_id is not null)
  )
);

create index if not exists erp_cash_vouchers_company_date_idx
  on public.erp_cash_vouchers(company_id, voucher_date);
create index if not exists erp_cash_vouchers_source_idx
  on public.erp_cash_vouchers(source_cashbox_id, status);
create unique index if not exists erp_cash_vouchers_journal_unique
  on public.erp_cash_vouchers(journal_entry_id) where journal_entry_id is not null;

alter table public.erp_cash_vouchers enable row level security;
drop trigger if exists erp_cash_vouchers_updated_at on public.erp_cash_vouchers;
create trigger erp_cash_vouchers_updated_at before update on public.erp_cash_vouchers
for each row execute function public.erp_set_updated_at();

create or replace function public.erp_validate_cash_voucher_links()
returns trigger
language plpgsql
security invoker
set search_path = public
as $
declare
  v_source_branch uuid;
begin
  if new.branch_id is not null and not exists (
    select 1 from public.erp_branches b where b.id = new.branch_id and b.company_id = new.company_id
  ) then raise exception 'فرع السند لا يتبع الشركة نفسها'; end if;

  if not exists (
    select 1 from public.erp_cashboxes c
    join public.erp_accounts a on a.id = c.account_id and a.company_id = c.company_id
    where c.id = new.source_cashbox_id and c.company_id = new.company_id
      and c.is_active and a.is_active and a.is_postable
  ) then raise exception 'الخزينة المصدر غير نشطة أو غير مرتبطة بحساب أستاذ صالح'; end if;
  select branch_id into v_source_branch from public.erp_cashboxes
  where id = new.source_cashbox_id and company_id = new.company_id;
  if new.branch_id is null then new.branch_id := v_source_branch;
  elsif v_source_branch is not null and new.branch_id <> v_source_branch then
    raise exception 'فرع سند الخزينة يجب أن يطابق فرع خزينة المصدر';
  end if;

  if new.voucher_type = 'transfer' then
    if not exists (
      select 1 from public.erp_cashboxes c
      join public.erp_accounts a on a.id = c.account_id and a.company_id = c.company_id
      where c.id = new.destination_cashbox_id and c.company_id = new.company_id
        and c.is_active and a.is_active and a.is_postable
    ) then raise exception 'خزينة الاستلام غير نشطة أو غير مرتبطة بحساب أستاذ صالح'; end if;
    if (select src.account_id from public.erp_cashboxes src where src.id = new.source_cashbox_id)
       = (select dst.account_id from public.erp_cashboxes dst where dst.id = new.destination_cashbox_id) then
      raise exception 'يجب ربط كل خزينة بحساب أستاذ مختلف لإتمام التحويل';
    end if;
  else
    if not exists (
      select 1 from public.erp_accounts a where a.id = new.counter_account_id
        and a.company_id = new.company_id and a.is_active and a.is_postable
    ) then raise exception 'الحساب المقابل غير نشط أو لا يتبع الشركة نفسها'; end if;
    if new.counter_account_id = (
      select c.account_id from public.erp_cashboxes c
      where c.id = new.source_cashbox_id and c.company_id = new.company_id
    ) then raise exception 'الحساب المقابل لا يمكن أن يكون حساب الخزينة المصدر نفسه'; end if;
    if new.party_id is not null and not exists (
      select 1 from public.erp_parties p where p.id = new.party_id and p.company_id = new.company_id and p.is_active
    ) then raise exception 'الطرف غير نشط أو لا يتبع الشركة نفسها'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_cash_voucher_links_guard on public.erp_cash_vouchers;
create trigger erp_cash_voucher_links_guard
before insert or update of company_id, branch_id, voucher_type, source_cashbox_id,
  destination_cashbox_id, counter_account_id, party_id
on public.erp_cash_vouchers for each row execute function public.erp_validate_cash_voucher_links();


create or replace function public.erp_require_cash_voucher_draft()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status <> 'draft' or new.journal_entry_id is not null or new.posted_at is not null then
    raise exception 'يجب إنشاء سند الخزينة كمسودة دون قيد مرتبط';
  end if;
  return new;
end;
$$;

drop trigger if exists erp_cash_voucher_draft_insert_guard on public.erp_cash_vouchers;
create trigger erp_cash_voucher_draft_insert_guard
before insert on public.erp_cash_vouchers
for each row execute function public.erp_require_cash_voucher_draft();

-- Cash voucher headers become immutable after posting; corrections use reversal vouchers.
create or replace function public.erp_guard_cash_voucher_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status <> 'draft' then
    raise exception 'السند المرحّل غير قابل للتعديل؛ أنشئ مستند تصحيح معتمدًا';
  end if;
  if old.company_id is distinct from new.company_id
     or old.voucher_number is distinct from new.voucher_number
     or old.created_by is distinct from new.created_by then
    raise exception 'لا يمكن تغيير الشركة أو رقم السند أو منشئه';
  end if;
  if new.status not in ('draft','posted','cancelled') then
    raise exception 'حالة السند غير صحيحة';
  end if;
  if new.status = 'posted' then
    if new.journal_entry_id is null or not exists (
      select 1
      from public.erp_journal_entries j
      join public.erp_cashboxes src on src.id = new.source_cashbox_id
      left join public.erp_cashboxes dst on dst.id = new.destination_cashbox_id
      where j.id = new.journal_entry_id
        and j.company_id = new.company_id
        and j.status = 'posted'
        and j.entry_date = new.voucher_date
        and (select count(*) from public.erp_journal_lines l where l.entry_id = j.id) = 2
        and (select coalesce(sum(l.debit),0) from public.erp_journal_lines l where l.entry_id = j.id) = new.amount
        and (select coalesce(sum(l.credit),0) from public.erp_journal_lines l where l.entry_id = j.id) = new.amount
        and (
          (new.voucher_type = 'receipt' and exists (
            select 1 from public.erp_journal_lines l
            where l.entry_id = j.id and l.account_id = src.account_id
              and l.debit = new.amount and l.credit = 0
          ) and exists (
            select 1 from public.erp_journal_lines l
            where l.entry_id = j.id and l.account_id = new.counter_account_id
              and l.debit = 0 and l.credit = new.amount
          ))
          or
          (new.voucher_type = 'payment' and exists (
            select 1 from public.erp_journal_lines l
            where l.entry_id = j.id and l.account_id = new.counter_account_id
              and l.debit = new.amount and l.credit = 0
          ) and exists (
            select 1 from public.erp_journal_lines l
            where l.entry_id = j.id and l.account_id = src.account_id
              and l.debit = 0 and l.credit = new.amount
          ))
          or
          (new.voucher_type = 'transfer' and dst.id is not null and exists (
            select 1 from public.erp_journal_lines l
            where l.entry_id = j.id and l.account_id = dst.account_id
              and l.debit = new.amount and l.credit = 0
          ) and exists (
            select 1 from public.erp_journal_lines l
            where l.entry_id = j.id and l.account_id = src.account_id
              and l.debit = 0 and l.credit = new.amount
          ))
        )
    ) then
      raise exception 'لا يمكن ترحيل السند دون قيد يومية متوازن ومطابق لقيمته وخزينته';
    end if;
    if exists (
      select 1 from public.erp_cash_vouchers other_v
      where other_v.id <> new.id and other_v.journal_entry_id = new.journal_entry_id
    ) then raise exception 'قيد اليومية مرتبط بسند خزينة آخر'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_cash_voucher_immutable_guard on public.erp_cash_vouchers;
create trigger erp_cash_voucher_immutable_guard
before update on public.erp_cash_vouchers for each row execute function public.erp_guard_cash_voucher_update();
