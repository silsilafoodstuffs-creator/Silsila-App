alter table public.erp_cashboxes
  add column if not exists checkbook_sheet_count integer not null default 50
  check (checkbook_sheet_count between 1 and 1000);

create table if not exists public.erp_financial_policies (
  company_id uuid primary key references public.erp_companies(id) on delete restrict,
  cash_issue_mode text not null default 'direct' check (cash_issue_mode in ('direct','sales_order_only')),
  require_cash_order_approval boolean not null default true,
  allow_credit_cheques boolean not null default true,
  cheque_issue_date_edit_roles text[] not null default array['owner','admin','accountant']::text[],
  cheque_edit_roles text[] not null default array['owner','admin','accountant']::text[],
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_cash_orders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  order_no bigint generated always as identity,
  order_number text generated always as ('CO-' || lpad(order_no::text, 8, '0')) stored,
  order_date date not null default current_date,
  order_type text not null check (order_type in ('receipt','payment')),
  party_type text not null check (party_type in ('supplier','customer','expense','bank','cashbox')),
  party_id uuid,
  party_name text not null,
  counterparty_type text,
  counterparty_id uuid,
  counterparty_name text,
  amount numeric(18,2) not null check (amount > 0),
  description text not null default '',
  sales_document_id uuid references public.erp_sales_documents(id) on delete restrict,
  assigned_to_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'draft' check (status in ('draft','approved','converted','cancelled')),
  cash_voucher_id uuid references public.erp_cash_vouchers(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, order_no)
);
create index if not exists erp_cash_orders_company_date_idx on public.erp_cash_orders(company_id, order_date desc);
create index if not exists erp_cash_orders_assignee_idx on public.erp_cash_orders(company_id, assigned_to_user_id, status);

create table if not exists public.erp_cash_movements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  movement_no bigint generated always as identity,
  movement_number text generated always as ('CM-' || lpad(movement_no::text, 8, '0')) stored,
  movement_date date not null default current_date,
  movement_type text not null check (movement_type in ('receipt','payment','transfer')),
  from_type text not null check (from_type in ('supplier','customer','expense','bank','cashbox')),
  from_id uuid,
  from_name text not null,
  to_type text not null check (to_type in ('supplier','customer','expense','bank','cashbox')),
  to_id uuid,
  to_name text not null,
  amount numeric(18,2) not null check (amount > 0),
  description text not null default '',
  cash_order_id uuid references public.erp_cash_orders(id) on delete restrict,
  cash_voucher_id uuid references public.erp_cash_vouchers(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(company_id, movement_no),
  check (from_type <> to_type or from_id is distinct from to_id)
);
create index if not exists erp_cash_movements_company_date_idx on public.erp_cash_movements(company_id, movement_date desc);

create table if not exists public.erp_checkbooks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  book_no bigint generated always as identity,
  book_number text generated always as ('CB-' || lpad(book_no::text, 8, '0')) stored,
  bank_cashbox_id uuid not null references public.erp_cashboxes(id) on delete restrict,
  first_check_number bigint not null check (first_check_number > 0),
  sheet_count integer not null check (sheet_count between 1 and 1000),
  registered boolean not null default false,
  registered_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(company_id, book_no),
  unique(bank_cashbox_id, first_check_number)
);
create index if not exists erp_checkbooks_company_bank_idx on public.erp_checkbooks(company_id, bank_cashbox_id);

create table if not exists public.erp_cheques (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  checkbook_id uuid references public.erp_checkbooks(id) on delete restrict,
  bank_cashbox_id uuid not null references public.erp_cashboxes(id) on delete restrict,
  check_number bigint not null check (check_number > 0),
  cheque_type text not null default 'bank' check (cheque_type in ('bank','credit')),
  direction text not null check (direction in ('payment','receipt')),
  issue_date date not null default current_date,
  due_date date not null,
  amount numeric(18,2) not null check (amount > 0),
  payee_type text check (payee_type in ('supplier','customer','expense','bank','cashbox')),
  payee_id uuid,
  payee_name text not null default '',
  status text not null default 'available' check (status in ('available','issued','under_collection','paid','returned','cashed_from_cashbox','cancelled')),
  settlement_method text check (settlement_method in ('bank','cashbox')),
  settlement_cashbox_id uuid references public.erp_cashboxes(id) on delete restrict,
  settlement_date date,
  settlement_reference text,
  order_id uuid references public.erp_cash_orders(id) on delete restrict,
  movement_id uuid references public.erp_cash_movements(id) on delete restrict,
  notes text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_cashbox_id, check_number),
  check (due_date >= issue_date),
  check ((status in ('paid','returned','cashed_from_cashbox') and settlement_date is not null) or status not in ('paid','returned','cashed_from_cashbox')),
  check ((status = 'cashed_from_cashbox' and settlement_method = 'cashbox' and settlement_cashbox_id is not null) or status <> 'cashed_from_cashbox')
);
create index if not exists erp_cheques_company_due_idx on public.erp_cheques(company_id, cheque_type, direction, status, due_date);
create index if not exists erp_cheques_book_idx on public.erp_cheques(checkbook_id, check_number);

alter table public.erp_financial_policies enable row level security;
alter table public.erp_cash_orders enable row level security;
alter table public.erp_cash_movements enable row level security;
alter table public.erp_checkbooks enable row level security;
alter table public.erp_cheques enable row level security;

create policy erp_financial_policies_member_select on public.erp_financial_policies for select to authenticated
using (public.erp_user_can_access_company(company_id));
create policy erp_financial_policies_admin_write on public.erp_financial_policies for all to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

create policy erp_cash_orders_member_select on public.erp_cash_orders for select to authenticated
using (public.erp_user_can_access_company(company_id) and
  (assigned_to_user_id is null or assigned_to_user_id = (select auth.uid()) or
   public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[])));
create policy erp_cash_orders_operator_insert on public.erp_cash_orders for insert to authenticated
with check (status = 'draft' and (created_by is null or created_by = (select auth.uid())) and
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]));
create policy erp_cash_orders_operator_update on public.erp_cash_orders for update to authenticated
using (status = 'draft' and public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]))
with check (status in ('draft','approved','converted','cancelled') and public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]));

create policy erp_cash_movements_member_select on public.erp_cash_movements for select to authenticated
using (public.erp_user_can_access_company(company_id));
create policy erp_cash_movements_operator_insert on public.erp_cash_movements for insert to authenticated
with check ((created_by is null or created_by = (select auth.uid())) and
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]));

create policy erp_checkbooks_member_select on public.erp_checkbooks for select to authenticated
using (public.erp_user_can_access_company(company_id));
create policy erp_checkbooks_operator_insert on public.erp_checkbooks for insert to authenticated
with check (not registered and (created_by is null or created_by = (select auth.uid())) and
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]));
create policy erp_checkbooks_operator_update on public.erp_checkbooks for update to authenticated
using (not registered and public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','accountant']::text[]));

create policy erp_cheques_member_select on public.erp_cheques for select to authenticated
using (public.erp_user_can_access_company(company_id));
create policy erp_cheques_operator_insert on public.erp_cheques for insert to authenticated
with check (status in ('available','issued','under_collection') and
  (created_by is null or created_by = (select auth.uid())) and
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]));
create policy erp_cheques_operator_update on public.erp_cheques for update to authenticated
using (status not in ('paid','returned','cashed_from_cashbox','cancelled') and
  public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager','operator','accountant']::text[]));

grant select, insert, update on public.erp_financial_policies, public.erp_cash_orders, public.erp_cash_movements,
  public.erp_checkbooks, public.erp_cheques to authenticated;

create or replace function public.erp_register_checkbook(p_checkbook_id uuid)
returns integer language plpgsql security invoker set search_path = public as $$
declare b public.erp_checkbooks%rowtype; v_inserted integer;
begin
  select * into b from public.erp_checkbooks where id=p_checkbook_id for update;
  if not found then raise exception 'دفتر الشيكات غير موجود'; end if;
  if b.registered then raise exception 'تم تسجيل هذا الدفتر بالفعل'; end if;
  if not public.erp_user_has_company_role(b.company_id,array['owner','admin','manager','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية تسجيل دفتر الشيكات';
  end if;
  insert into public.erp_cheques(company_id,checkbook_id,bank_cashbox_id,check_number,cheque_type,direction,issue_date,amount,status,created_by)
  select b.company_id,b.id,b.bank_cashbox_id,b.first_check_number+g.n,'bank','payment',current_date,0.01,'available',auth.uid()
  from generate_series(0,b.sheet_count-1) as g(n);
  get diagnostics v_inserted=row_count;
  update public.erp_checkbooks set registered=true,registered_at=now() where id=b.id;
  return v_inserted;
end; $$;
revoke all on function public.erp_register_checkbook(uuid) from public,anon;
grant execute on function public.erp_register_checkbook(uuid) to authenticated;

create or replace function public.erp_settle_cheque(
  p_cheque_id uuid,p_result text,p_settlement_date date,p_method text default 'bank',
  p_cashbox_id uuid default null,p_reference text default null
) returns void language plpgsql security invoker set search_path=public as $$
declare c public.erp_cheques%rowtype;
begin
  select * into c from public.erp_cheques where id=p_cheque_id for update;
  if not found then raise exception 'الشيك غير موجود'; end if;
  if not public.erp_user_has_company_role(c.company_id,array['owner','admin','manager','accountant']::text[]) then raise exception 'ليست لديك صلاحية تسوية الشيكات'; end if;
  if c.cheque_type<>'bank' then raise exception 'شيكات الائتمان لا تظهر في متابعة الشيكات البنكية'; end if;
  if c.status not in ('issued','under_collection') then raise exception 'حالة الشيك لا تسمح بالتسوية'; end if;
  if p_result not in ('paid','returned','cashed_from_cashbox') or p_settlement_date is null then raise exception 'نتيجة أو تاريخ التسوية غير صحيح'; end if;
  if p_result='cashed_from_cashbox' and (p_method<>'cashbox' or p_cashbox_id is null) then raise exception 'حدد الخزينة التي تم الصرف منها'; end if;
  update public.erp_cheques set status=p_result,settlement_date=p_settlement_date,settlement_method=p_method,
    settlement_cashbox_id=p_cashbox_id,settlement_reference=nullif(trim(p_reference),''),updated_by=auth.uid(),updated_at=now()
  where id=p_cheque_id;
end; $$;
revoke all on function public.erp_settle_cheque(uuid,text,date,text,uuid,text) from public,anon;
grant execute on function public.erp_settle_cheque(uuid,text,date,text,uuid,text) to authenticated;

create or replace function public.erp_issue_cheque(
  p_cheque_id uuid,p_cheque_type text,p_direction text,p_issue_date date,p_due_date date,
  p_amount numeric,p_payee_type text,p_payee_id uuid,p_payee_name text,p_notes text default ''
) returns void language plpgsql security invoker set search_path=public as $$
declare c public.erp_cheques%rowtype;
begin
  select * into c from public.erp_cheques where id=p_cheque_id for update;
  if not found then raise exception 'رقم الشيك غير موجود في دفتر مسجل'; end if;
  if c.status<>'available' then raise exception 'لا يمكن اختيار إلا شيك متاح غير مستخدم'; end if;
  if p_cheque_type not in ('bank','credit') or p_direction not in ('payment','receipt') then raise exception 'نوع الشيك أو اتجاهه غير صحيح'; end if;
  if p_cheque_type='credit' and not coalesce((select allow_credit_cheques from public.erp_financial_policies where company_id=c.company_id),true) then raise exception 'شيكات الائتمان غير مفعلة في السياسات المحاسبية'; end if;
  if not public.erp_user_has_company_role(c.company_id,array['owner','admin','manager','operator','accountant']::text[]) then raise exception 'ليست لديك صلاحية إصدار الشيك'; end if;
  if p_issue_date is null or p_due_date<p_issue_date or p_amount<=0 then raise exception 'راجع تاريخ الإصدار والاستحقاق والقيمة'; end if;
  update public.erp_cheques set cheque_type=p_cheque_type,direction=p_direction,issue_date=p_issue_date,due_date=p_due_date,
    amount=p_amount,payee_type=p_payee_type,payee_id=p_payee_id,payee_name=coalesce(p_payee_name,''),
    status=case when p_direction='receipt' then 'under_collection' else 'issued' end,
    notes=coalesce(p_notes,''),updated_by=auth.uid(),updated_at=now() where id=p_cheque_id;
end; $$;
revoke all on function public.erp_issue_cheque(uuid,text,text,date,date,numeric,text,uuid,text,text) from public,anon;
grant execute on function public.erp_issue_cheque(uuid,text,text,date,date,numeric,text,uuid,text,text) to authenticated;
