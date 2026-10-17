-- Accounting integration for already-posted purchase and sales documents.
-- Apply after erp_schema.sql, erp_operations_schema.sql, erp_journal_workflow.sql,
-- erp_inventory_workflow.sql, erp_operations_workflow.sql and erp_security_membership.sql.
-- This migration creates explicit company-level ledger mappings and an idempotent posting RPC.

create table if not exists public.erp_operational_account_mappings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null unique references public.erp_companies(id) on delete cascade,
  accounts_receivable_account_id uuid not null references public.erp_accounts(id) on delete restrict,
  accounts_payable_account_id uuid not null references public.erp_accounts(id) on delete restrict,
  sales_revenue_account_id uuid not null references public.erp_accounts(id) on delete restrict,
  sales_returns_account_id uuid not null references public.erp_accounts(id) on delete restrict,
  inventory_account_id uuid not null references public.erp_accounts(id) on delete restrict,
  cost_of_goods_sold_account_id uuid not null references public.erp_accounts(id) on delete restrict,
  sales_tax_payable_account_id uuid references public.erp_accounts(id) on delete restrict,
  purchase_tax_credit_account_id uuid references public.erp_accounts(id) on delete restrict,
  purchase_return_variance_account_id uuid not null references public.erp_accounts(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.erp_operational_account_mappings enable row level security;
drop trigger if exists erp_operational_account_mappings_updated_at on public.erp_operational_account_mappings;
create trigger erp_operational_account_mappings_updated_at
before update on public.erp_operational_account_mappings
for each row execute function public.erp_set_updated_at();

create or replace function public.erp_validate_operational_account_mappings()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_account_id uuid;
  v_company_id uuid;
begin
  if (
    select count(*) from unnest(array[
      new.accounts_receivable_account_id,
      new.accounts_payable_account_id,
      new.sales_revenue_account_id,
      new.sales_returns_account_id,
      new.inventory_account_id,
      new.cost_of_goods_sold_account_id,
      new.purchase_return_variance_account_id,
      new.sales_tax_payable_account_id,
      new.purchase_tax_credit_account_id
    ]) as x(account_id) where account_id is not null
  ) <> (
    select count(distinct account_id) from unnest(array[
      new.accounts_receivable_account_id,
      new.accounts_payable_account_id,
      new.sales_revenue_account_id,
      new.sales_returns_account_id,
      new.inventory_account_id,
      new.cost_of_goods_sold_account_id,
      new.purchase_return_variance_account_id,
      new.sales_tax_payable_account_id,
      new.purchase_tax_credit_account_id
    ]) as x(account_id) where account_id is not null
  ) then
    raise exception 'لا يمكن استخدام حساب الأستاذ نفسه لأكثر من دور في خريطة الحسابات التشغيلية';
  end if;

  foreach v_account_id in array array[
    new.accounts_receivable_account_id,
    new.accounts_payable_account_id,
    new.sales_revenue_account_id,
    new.sales_returns_account_id,
    new.inventory_account_id,
    new.cost_of_goods_sold_account_id,
    new.purchase_return_variance_account_id,
    new.sales_tax_payable_account_id,
    new.purchase_tax_credit_account_id
  ]
  loop
    if v_account_id is null then continue; end if;
    select a.company_id into v_company_id
    from public.erp_accounts a
    where a.id = v_account_id and a.is_active and a.is_postable;
    if v_company_id is distinct from new.company_id then
      raise exception 'كل حسابات الربط يجب أن تكون نشطة وقابلة للترحيل وتتبع الشركة نفسها';
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists erp_operational_account_mappings_guard on public.erp_operational_account_mappings;
create trigger erp_operational_account_mappings_guard
before insert or update on public.erp_operational_account_mappings
for each row execute function public.erp_validate_operational_account_mappings();

drop policy if exists erp_operational_account_mappings_select_member on public.erp_operational_account_mappings;
create policy erp_operational_account_mappings_select_member
on public.erp_operational_account_mappings for select to authenticated
using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_operational_account_mappings_write_accounting on public.erp_operational_account_mappings;
create policy erp_operational_account_mappings_write_accounting
on public.erp_operational_account_mappings for all to authenticated
using (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]))
with check (public.erp_user_has_company_role(company_id, array['owner','admin','accountant']::text[]));

grant select, insert, update on public.erp_operational_account_mappings to authenticated;

create unique index if not exists erp_operational_accounting_source_unique
on public.erp_journal_entries(company_id, source_type, source_id)
where source_type in ('purchase_accounting','sales_accounting') and source_id is not null;

create or replace function public.erp_post_operational_document_accounting(
  p_document_id uuid,
  p_kind text
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_company_id uuid;
  v_branch_id uuid;
  v_party_id uuid;
  v_doc_date date;
  v_doc_number text;
  v_doc_type text;
  v_status text;
  v_subtotal numeric(14,2);
  v_discount numeric(14,2);
  v_tax numeric(14,2);
  v_total numeric(14,2);
  v_cost numeric(14,2);
  v_net numeric(14,2);
  v_variance numeric(14,2);
  v_mapping public.erp_operational_account_mappings%rowtype;
  v_entry_id uuid;
  v_source_type text;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_account_id uuid;
  v_debit numeric(14,2);
  v_credit numeric(14,2);
  v_description text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولًا'; end if;
  if p_kind not in ('purchase','sales') then raise exception 'نوع المستند غير مدعوم'; end if;

  if p_kind = 'purchase' then
    select company_id, branch_id, supplier_id, document_date, document_number, document_type,
      status, subtotal, discount_total, tax_total, grand_total
    into v_company_id, v_branch_id, v_party_id, v_doc_date, v_doc_number, v_doc_type,
      v_status, v_subtotal, v_discount, v_tax, v_total
    from public.erp_purchase_documents where id = p_document_id for update;
    v_source_type := 'purchase_accounting';
  else
    select company_id, branch_id, customer_id, document_date, document_number, document_type,
      status, subtotal, discount_total, tax_total, grand_total
    into v_company_id, v_branch_id, v_party_id, v_doc_date, v_doc_number, v_doc_type,
      v_status, v_subtotal, v_discount, v_tax, v_total
    from public.erp_sales_documents where id = p_document_id for update;
    v_source_type := 'sales_accounting';
  end if;

  if v_company_id is null then raise exception 'المستند غير موجود'; end if;
  if not public.erp_user_has_company_role(v_company_id, array['owner','admin','accountant']::text[]) then
    raise exception 'ترحيل الأثر المحاسبي يتطلب صلاحية محاسب أو مدير';
  end if;
  if v_status <> 'posted' then raise exception 'يجب ترحيل المستند المخزني أولًا'; end if;
  if p_kind = 'purchase' and v_doc_type not in ('receipt','invoice','return') then
    raise exception 'نوع مستند المشتريات لا ينشئ أثرًا محاسبيًا مخزنيًا';
  end if;
  if p_kind = 'sales' and v_doc_type not in ('delivery','invoice','return') then
    raise exception 'نوع مستند المبيعات لا ينشئ أثرًا محاسبيًا مخزنيًا';
  end if;

  select id into v_entry_id from public.erp_journal_entries
  where company_id = v_company_id and source_type = v_source_type and source_id = p_document_id
    and status = 'posted' limit 1;
  if v_entry_id is not null then return v_entry_id; end if;
  if exists (select 1 from public.erp_journal_entries
    where company_id = v_company_id and source_type = v_source_type and source_id = p_document_id) then
    raise exception 'يوجد قيد محاسبي مسودة مرتبط بالمستند؛ راجعه قبل إعادة المحاولة';
  end if;

  select * into v_mapping from public.erp_operational_account_mappings
  where company_id = v_company_id;
  if not found then raise exception 'يجب إعداد خريطة الحسابات التشغيلية للشركة أولًا'; end if;

  v_net := round(v_subtotal - v_discount, 2);
  if v_net < 0 or v_total <> round(v_net + v_tax, 2) then
    raise exception 'إجماليات المستند غير متوازنة؛ راجع الخصم والضريبة قبل الترحيل المحاسبي';
  end if;

  select coalesce(sum(
    case
      when p_kind = 'sales' and v_doc_type = 'return' and m.movement_type = 'customer_return'
        then m.quantity_in * m.unit_cost
      when p_kind = 'sales' and v_doc_type <> 'return' and m.movement_type = 'sales_issue'
        then m.quantity_out * m.unit_cost
      when p_kind = 'purchase' and v_doc_type = 'return' and m.movement_type = 'supplier_return'
        then m.quantity_out * m.unit_cost
      else 0
    end
  ),0)::numeric(14,2)
  into v_cost
  from public.erp_inventory_movements m
  where m.company_id = v_company_id
    and m.reference_id = p_document_id
    and m.reference_type = case when p_kind = 'purchase' then 'purchase_document' else 'sales_document' end;

  if v_cost <= 0 and p_kind = 'sales' and v_doc_type <> 'return' then
    raise exception 'تعذر تحديد تكلفة البضاعة المباعة من حركات المخزون';
  end if;

  if p_kind = 'sales' then
    if v_doc_type = 'return' then
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.sales_returns_account_id,'debit',v_net,'credit',0,'description','مرتجع مبيعات ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.accounts_receivable_account_id,'debit',0,'credit',v_total,'description','تخفيض مديونية عميل - ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id)
      );
      if v_tax > 0 then
        if v_mapping.sales_tax_payable_account_id is null then raise exception 'حدد حساب ضريبة المبيعات قبل ترحيل هذا المستند'; end if;
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.sales_tax_payable_account_id,'debit',v_tax,'credit',0,'description','عكس ضريبة مبيعات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
      if v_cost > 0 then
        v_lines := v_lines || jsonb_build_array(
          jsonb_build_object('account_id',v_mapping.inventory_account_id,'debit',v_cost,'credit',0,'description','إعادة مخزون مرتجع مبيعات ' || v_doc_number,'branch_id',v_branch_id),
          jsonb_build_object('account_id',v_mapping.cost_of_goods_sold_account_id,'debit',0,'credit',v_cost,'description','عكس تكلفة بضاعة مرتجعة ' || v_doc_number,'branch_id',v_branch_id)
        );
      end if;
    else
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.accounts_receivable_account_id,'debit',v_total,'credit',0,'description','مبيعات ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.sales_revenue_account_id,'debit',0,'credit',v_net,'description','إيراد مبيعات ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id)
      );
      if v_tax > 0 then
        if v_mapping.sales_tax_payable_account_id is null then raise exception 'حدد حساب ضريبة المبيعات قبل ترحيل هذا المستند'; end if;
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.sales_tax_payable_account_id,'debit',0,'credit',v_tax,'description','ضريبة مبيعات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.cost_of_goods_sold_account_id,'debit',v_cost,'credit',0,'description','تكلفة بضاعة مباعة ' || v_doc_number,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.inventory_account_id,'debit',0,'credit',v_cost,'description','تخفيض المخزون - ' || v_doc_number,'branch_id',v_branch_id)
      );
    end if;
  else
    if v_doc_type = 'return' then
      if v_tax > 0 and v_mapping.purchase_tax_credit_account_id is null then
        raise exception 'حدد حساب ضريبة المدخلات قبل ترحيل مرتجع المشتريات';
      end if;
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.accounts_payable_account_id,'debit',v_total,'credit',0,'description','مرتجع مشتريات ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.inventory_account_id,'debit',0,'credit',v_cost,'description','تخفيض مخزون مرتجع مشتريات ' || v_doc_number,'branch_id',v_branch_id)
      );
      if v_tax > 0 then
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.purchase_tax_credit_account_id,'debit',0,'credit',v_tax,'description','عكس ضريبة مشتريات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
      v_variance := round(v_total - v_tax - v_cost, 2);
      if v_variance > 0 then
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.purchase_return_variance_account_id,'debit',0,'credit',v_variance,'description','فرق تقييم مرتجع مشتريات ' || v_doc_number,'branch_id',v_branch_id));
      elsif v_variance < 0 then
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.purchase_return_variance_account_id,'debit',abs(v_variance),'credit',0,'description','فرق تقييم مرتجع مشتريات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
    else
      if v_tax > 0 and v_mapping.purchase_tax_credit_account_id is null then
        raise exception 'حدد حساب ضريبة المدخلات قبل ترحيل هذا المستند';
      end if;
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.inventory_account_id,'debit',v_net,'credit',0,'description','مخزون مشتريات ' || v_doc_number,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.accounts_payable_account_id,'debit',0,'credit',v_total,'description','مستحق للمورد ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id)
      );
      if v_tax > 0 then
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.purchase_tax_credit_account_id,'debit',v_tax,'credit',0,'description','ضريبة مدخلات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
    end if;
  end if;

  insert into public.erp_journal_entries(
    company_id, branch_id, fiscal_period_id, entry_date, description,
    source_type, source_id, status, created_by
  ) values (
    v_company_id, v_branch_id,
    (select fp.id from public.erp_fiscal_periods fp where fp.company_id = v_company_id
      and v_doc_date between fp.starts_on and fp.ends_on order by fp.starts_on desc limit 1),
    v_doc_date, 'قيد آلي للمستند ' || v_doc_number, v_source_type, p_document_id, 'draft', auth.uid()
  ) returning id into v_entry_id;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    v_account_id := nullif(v_line->>'account_id','')::uuid;
    v_debit := coalesce(nullif(v_line->>'debit','')::numeric,0);
    v_credit := coalesce(nullif(v_line->>'credit','')::numeric,0);
    v_description := nullif(v_line->>'description','');
    if v_account_id is null or not ((v_debit > 0 and v_credit = 0) or (v_credit > 0 and v_debit = 0)) then
      if v_debit = 0 and v_credit = 0 then continue; end if;
      raise exception 'سطر قيد آلي غير صالح؛ راجع خريطة الحسابات وقيم المستند';
    end if;
    if not exists (select 1 from public.erp_accounts a where a.id = v_account_id and a.company_id = v_company_id and a.is_active and a.is_postable) then
      raise exception 'أحد حسابات الربط غير نشط أو لا يتبع الشركة أو غير قابل للترحيل';
    end if;
    insert into public.erp_journal_lines(entry_id, account_id, description, debit, credit, party_id, branch_id)
    values (v_entry_id, v_account_id, v_description, v_debit, v_credit,
      nullif(v_line->>'party_id','')::uuid, nullif(v_line->>'branch_id','')::uuid);
  end loop;

  perform public.erp_post_journal_entry(v_entry_id);
  return v_entry_id;
end;
$$;

revoke all on function public.erp_post_operational_document_accounting(uuid,text) from public, anon;
grant execute on function public.erp_post_operational_document_accounting(uuid,text) to authenticated;

comment on function public.erp_post_operational_document_accounting(uuid,text) is
  'Creates an idempotent balanced general-ledger entry for an already-posted purchase/sales document using explicit company account mappings.';
