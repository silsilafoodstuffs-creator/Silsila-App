-- Silsila operational document integrity and posting workflow.
-- Apply after erp_operations_schema.sql, erp_security_membership.sql and erp_inventory_workflow.sql.

create or replace function public.erp_validate_operational_company_links()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_company uuid;
  v_party_kind text;
  v_document_company uuid;
begin
  if tg_table_name = 'erp_purchase_documents' then
    select company_id, party_kind into v_company, v_party_kind
    from public.erp_parties where id = new.supplier_id;
    if v_company is distinct from new.company_id or v_party_kind not in ('supplier','both') then
      raise exception 'المورد يجب أن يكون موردًا تابعًا للشركة نفسها';
    end if;
    if new.warehouse_id is not null and not exists (
      select 1 from public.erp_warehouses w where w.id = new.warehouse_id and w.company_id = new.company_id
    ) then raise exception 'مخزن المشتريات لا يتبع الشركة نفسها'; end if;
    if new.branch_id is not null and not exists (
      select 1 from public.erp_branches b where b.id = new.branch_id and b.company_id = new.company_id
    ) then raise exception 'فرع المشتريات لا يتبع الشركة نفسها'; end if;
  elsif tg_table_name = 'erp_sales_documents' then
    select company_id, party_kind into v_company, v_party_kind
    from public.erp_parties where id = new.customer_id;
    if v_company is distinct from new.company_id or v_party_kind not in ('customer','both') then
      raise exception 'العميل يجب أن يكون عميلًا تابعًا للشركة نفسها';
    end if;
    if new.warehouse_id is not null and not exists (
      select 1 from public.erp_warehouses w where w.id = new.warehouse_id and w.company_id = new.company_id
    ) then raise exception 'مخزن المبيعات لا يتبع الشركة نفسها'; end if;
    if new.branch_id is not null and not exists (
      select 1 from public.erp_branches b where b.id = new.branch_id and b.company_id = new.company_id
    ) then raise exception 'فرع المبيعات لا يتبع الشركة نفسها'; end if;
  elsif tg_table_name = 'erp_purchase_lines' then
    select d.company_id into v_document_company from public.erp_purchase_documents d where d.id = new.document_id;
    if v_document_company is null or not exists (
      select 1 from public.erp_items i where i.id = new.item_id and i.company_id = v_document_company
    ) then raise exception 'بند المشتريات يجب أن يشير إلى صنف من شركة المستند'; end if;
  elsif tg_table_name = 'erp_sales_lines' then
    select d.company_id into v_document_company from public.erp_sales_documents d where d.id = new.document_id;
    if v_document_company is null or not exists (
      select 1 from public.erp_items i where i.id = new.item_id and i.company_id = v_document_company
    ) then raise exception 'بند المبيعات يجب أن يشير إلى صنف من شركة المستند'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_purchase_document_company_guard on public.erp_purchase_documents;
create trigger erp_purchase_document_company_guard
before insert or update of company_id, supplier_id, warehouse_id, branch_id
on public.erp_purchase_documents for each row execute function public.erp_validate_operational_company_links();

drop trigger if exists erp_sales_document_company_guard on public.erp_sales_documents;
create trigger erp_sales_document_company_guard
before insert or update of company_id, customer_id, warehouse_id, branch_id
on public.erp_sales_documents for each row execute function public.erp_validate_operational_company_links();

drop trigger if exists erp_purchase_line_company_guard on public.erp_purchase_lines;
create trigger erp_purchase_line_company_guard
before insert or update of document_id, item_id
on public.erp_purchase_lines for each row execute function public.erp_validate_operational_company_links();

drop trigger if exists erp_sales_line_company_guard on public.erp_sales_lines;
create trigger erp_sales_line_company_guard
before insert or update of document_id, item_id
on public.erp_sales_lines for each row execute function public.erp_validate_operational_company_links();


-- Direct status updates cannot bypass posting: a posted operational document must
-- already have its matching movement ledger rows, and posted headers are immutable.
create or replace function public.erp_guard_operational_document_update()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_lines bigint;
  v_movements bigint;
  v_reference text;
begin
  if old.status = 'posted' then
    raise exception 'المستند المرحّل غير قابل للتعديل';
  end if;
  if old.company_id is distinct from new.company_id
     or old.document_number is distinct from new.document_number
     or old.created_by is distinct from new.created_by then
    raise exception 'لا يمكن تغيير الشركة أو رقم المستند أو منشئه';
  end if;
  if new.status = 'posted' then
    if tg_table_name = 'erp_purchase_documents' then
      v_reference := 'purchase_document';
      select count(*) into v_lines from public.erp_purchase_lines where document_id = old.id;
    else
      v_reference := 'sales_document';
      select count(*) into v_lines from public.erp_sales_lines where document_id = old.id;
    end if;
    select count(*) into v_movements
    from public.erp_inventory_movements m
    where m.company_id = old.company_id
      and m.reference_type = v_reference
      and m.reference_id = old.id;
    if v_lines = 0 or v_movements < v_lines then
      raise exception 'لا يمكن ترحيل المستند قبل إنشاء حركات المخزون المطابقة لكل بند';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_purchase_document_post_guard on public.erp_purchase_documents;
create trigger erp_purchase_document_post_guard
before update on public.erp_purchase_documents
for each row execute function public.erp_guard_operational_document_update();

drop trigger if exists erp_sales_document_post_guard on public.erp_sales_documents;
create trigger erp_sales_document_post_guard
before update on public.erp_sales_documents
for each row execute function public.erp_guard_operational_document_update();

create or replace function public.erp_post_purchase_document(p_document_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_doc public.erp_purchase_documents%rowtype;
  v_line record;
  v_count integer := 0;
  v_movement_type text;
begin
  select * into v_doc from public.erp_purchase_documents where id = p_document_id for update;
  if not found then raise exception 'مستند المشتريات غير موجود'; end if;
  if not public.erp_user_has_company_role(v_doc.company_id, array['owner','admin','manager','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية ترحيل مستند المشتريات';
  end if;
  if v_doc.status not in ('draft','approved') then raise exception 'يمكن ترحيل المسودة أو المستند المعتمد فقط'; end if;
  if v_doc.document_type not in ('receipt','invoice','return') then
    raise exception 'نوع المستند لا ينشئ حركة مخزنية؛ لا يمكن ترحيله كاستلام';
  end if;
  if v_doc.warehouse_id is null then raise exception 'اختر مخزنًا للمستند قبل الترحيل'; end if;
  if not exists (select 1 from public.erp_warehouses w where w.id = v_doc.warehouse_id and w.company_id = v_doc.company_id and w.is_active) then
    raise exception 'المخزن غير نشط أو لا يتبع الشركة'; end if;
  select count(*) into v_count from public.erp_purchase_lines where document_id = v_doc.id;
  if v_count = 0 then raise exception 'لا يمكن ترحيل مستند مشتريات بلا بنود'; end if;

  v_movement_type := case when v_doc.document_type = 'return' then 'supplier_return' else 'purchase_receipt' end;
  for v_line in
    select l.* from public.erp_purchase_lines l where l.document_id = v_doc.id order by l.created_at, l.id
  loop
    perform public.erp_record_inventory_movement(
      v_doc.company_id, v_doc.warehouse_id, v_line.item_id, v_movement_type,
      v_line.quantity, v_line.unit_price, v_doc.branch_id, v_doc.document_date::timestamptz,
      'purchase_document', v_doc.id, v_line.batch_number, v_line.expiry_date,
      'مستند مشتريات ' || v_doc.document_number
    );
  end loop;

  update public.erp_purchase_documents set status = 'posted', updated_at = now() where id = v_doc.id;
  return v_doc.id;
end;
$$;

create or replace function public.erp_post_sales_document(p_document_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_doc public.erp_sales_documents%rowtype;
  v_line record;
  v_count integer := 0;
  v_movement_type text;
begin
  select * into v_doc from public.erp_sales_documents where id = p_document_id for update;
  if not found then raise exception 'مستند المبيعات غير موجود'; end if;
  if not public.erp_user_has_company_role(v_doc.company_id, array['owner','admin','manager','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية ترحيل مستند المبيعات';
  end if;
  if v_doc.status not in ('draft','approved') then raise exception 'يمكن ترحيل المسودة أو المستند المعتمد فقط'; end if;
  if v_doc.document_type not in ('delivery','invoice','return') then
    raise exception 'نوع المستند لا ينشئ حركة مخزنية؛ لا يمكن ترحيله كصرف';
  end if;
  if v_doc.warehouse_id is null then raise exception 'اختر مخزنًا للمستند قبل الترحيل'; end if;
  if not exists (select 1 from public.erp_warehouses w where w.id = v_doc.warehouse_id and w.company_id = v_doc.company_id and w.is_active) then
    raise exception 'المخزن غير نشط أو لا يتبع الشركة'; end if;
  select count(*) into v_count from public.erp_sales_lines where document_id = v_doc.id;
  if v_count = 0 then raise exception 'لا يمكن ترحيل مستند مبيعات بلا بنود'; end if;

  v_movement_type := case when v_doc.document_type = 'return' then 'customer_return' else 'sales_issue' end;
  for v_line in
    select l.* from public.erp_sales_lines l where l.document_id = v_doc.id order by l.created_at, l.id
  loop
    perform public.erp_record_inventory_movement(
      v_doc.company_id, v_doc.warehouse_id, v_line.item_id, v_movement_type,
      v_line.quantity, v_line.unit_price, v_doc.branch_id, v_doc.document_date::timestamptz,
      'sales_document', v_doc.id, v_line.batch_number, v_line.expiry_date,
      'مستند مبيعات ' || v_doc.document_number
    );
  end loop;

  update public.erp_sales_documents set status = 'posted', updated_at = now() where id = v_doc.id;
  return v_doc.id;
end;
$$;

revoke all on function public.erp_post_purchase_document(uuid) from public, anon;
revoke all on function public.erp_post_sales_document(uuid) from public, anon;
grant execute on function public.erp_post_purchase_document(uuid) to authenticated;
grant execute on function public.erp_post_sales_document(uuid) to authenticated;

comment on function public.erp_post_purchase_document(uuid) is
  'Posts an eligible purchase receipt/invoice or supplier return and creates stock movements in the same transaction.';
comment on function public.erp_post_sales_document(uuid) is
  'Posts an eligible delivery/invoice or customer return and creates stock movements in the same transaction.';
