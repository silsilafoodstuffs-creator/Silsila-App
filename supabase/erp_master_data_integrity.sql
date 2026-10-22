-- Master-data tenant and accounting link integrity.
-- Apply after erp_schema.sql and erp_master_data_schema.sql.

create or replace function public.erp_validate_master_data_links()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_company uuid;
  v_postable boolean;
  v_active boolean;
  v_cycle boolean;
begin
  if tg_table_name = 'erp_warehouses' then
    if new.branch_id is not null then
      select company_id, is_active into v_company, v_active from public.erp_branches where id = new.branch_id;
      if v_company is distinct from new.company_id or v_active is distinct from true then
        raise exception 'فرع المخزن غير نشط أو لا يتبع الشركة نفسها';
      end if;
    end if;
  elsif tg_table_name = 'erp_item_categories' then
    if new.parent_id is not null then
      select company_id into v_company from public.erp_item_categories where id = new.parent_id;
      if v_company is distinct from new.company_id then
        raise exception 'الفئة الأب يجب أن تتبع الشركة نفسها';
      end if;
      with recursive descendants(id, path) as (
        select new.id, array[new.id]::uuid[]
        union all
        select child.id, d.path || child.id
        from descendants d join public.erp_item_categories child on child.parent_id = d.id
        where not child.id = any(d.path)
      )
      select exists(select 1 from descendants where id = new.parent_id) into v_cycle;
      if coalesce(v_cycle, false) then raise exception 'لا يمكن وضع الفئة تحت أحد أحفادها'; end if;
    end if;
  elsif tg_table_name = 'erp_items' then
    if new.category_id is not null then
      select company_id, is_active into v_company, v_active from public.erp_item_categories where id = new.category_id;
      if v_company is distinct from new.company_id or v_active is distinct from true then
        raise exception 'فئة الصنف غير نشطة أو لا تتبع الشركة نفسها';
      end if;
    end if;
  elsif tg_table_name = 'erp_cashboxes' then
    if new.branch_id is not null then
      select company_id, is_active into v_company, v_active from public.erp_branches where id = new.branch_id;
      if v_company is distinct from new.company_id or v_active is distinct from true then
        raise exception 'فرع الخزينة غير نشط أو لا يتبع الشركة نفسها';
      end if;
    end if;
    if new.account_id is not null then
      select company_id, is_postable, is_active into v_company, v_postable, v_active
      from public.erp_accounts where id = new.account_id;
      if v_company is distinct from new.company_id or v_postable is distinct from true or v_active is distinct from true then
        raise exception 'حساب الخزينة يجب أن يكون نشطًا وتحليليًا وتابعًا للشركة نفسها';
      end if;
    end if;
  elsif tg_table_name = 'erp_item_units' then
    select company_id into v_company from public.erp_items where id = new.item_id;
    if v_company is distinct from new.company_id then
      raise exception 'وحدة الصنف يجب أن تتبع الشركة نفسها';
    end if;
  elsif tg_table_name = 'erp_party_contacts' then
    select company_id into v_company from public.erp_parties where id = new.party_id;
    if v_company is distinct from new.company_id then
      raise exception 'جهة اتصال الطرف يجب أن تتبع الشركة نفسها';
    end if;
  elsif tg_table_name = 'erp_price_list_lines' then
    if not exists (select 1 from public.erp_price_lists p where p.id = new.price_list_id and p.company_id = new.company_id) then
      raise exception 'قائمة الأسعار يجب أن تتبع الشركة نفسها';
    end if;
    if not exists (select 1 from public.erp_items i where i.id = new.item_id and i.company_id = new.company_id) then
      raise exception 'الصنف في سطر قائمة الأسعار يجب أن يتبع الشركة نفسها';
    end if;
    if new.item_unit_id is not null and not exists (
      select 1 from public.erp_item_units u where u.id = new.item_unit_id and u.item_id = new.item_id and u.company_id = new.company_id
    ) then raise exception 'وحدة السعر يجب أن تكون وحدة معرفة للصنف نفسه'; end if;
  elsif tg_table_name = 'erp_party_price_lists' then
    if not exists (select 1 from public.erp_parties p where p.id = new.party_id and p.company_id = new.company_id) then
      raise exception 'الطرف المرتبط بقائمة الأسعار يجب أن يتبع الشركة نفسها';
    end if;
    if not exists (select 1 from public.erp_price_lists p where p.id = new.price_list_id and p.company_id = new.company_id) then
      raise exception 'قائمة أسعار الطرف يجب أن تتبع الشركة نفسها';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists erp_warehouse_branch_guard on public.erp_warehouses;
create trigger erp_warehouse_branch_guard
before insert or update of company_id, branch_id on public.erp_warehouses
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_item_category_parent_guard on public.erp_item_categories;
create trigger erp_item_category_parent_guard
before insert or update of company_id, parent_id on public.erp_item_categories
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_item_category_guard on public.erp_items;
create trigger erp_item_category_guard
before insert or update of company_id, category_id on public.erp_items
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_cashbox_account_guard on public.erp_cashboxes;
create trigger erp_cashbox_account_guard
before insert or update of company_id, branch_id, account_id on public.erp_cashboxes
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_item_unit_company_guard on public.erp_item_units;
create trigger erp_item_unit_company_guard
before insert or update of company_id, item_id on public.erp_item_units
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_party_contact_company_guard on public.erp_party_contacts;
create trigger erp_party_contact_company_guard
before insert or update of company_id, party_id on public.erp_party_contacts
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_price_list_line_company_guard on public.erp_price_list_lines;
create trigger erp_price_list_line_company_guard
before insert or update of company_id, price_list_id, item_id, item_unit_id on public.erp_price_list_lines
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_party_price_list_company_guard on public.erp_party_price_lists;
create trigger erp_party_price_list_company_guard
before insert or update of company_id, party_id, price_list_id on public.erp_party_price_lists
for each row execute function public.erp_validate_master_data_links();

comment on function public.erp_validate_master_data_links() is
  'Validates company-scoped links for branches, item groups, cashboxes, item units, party contacts, and price list assignments.';
