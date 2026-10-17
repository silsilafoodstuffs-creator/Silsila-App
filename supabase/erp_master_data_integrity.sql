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
begin
  if tg_table_name = 'erp_warehouses' then
    if new.branch_id is not null then
      select company_id into v_company from public.erp_branches where id = new.branch_id;
      if v_company is distinct from new.company_id then
        raise exception 'فرع المخزن يجب أن يتبع الشركة نفسها';
      end if;
    end if;
  elsif tg_table_name = 'erp_items' then
    if new.group_id is not null then
      select company_id into v_company from public.erp_item_groups where id = new.group_id;
      if v_company is distinct from new.company_id then
        raise exception 'مجموعة الصنف يجب أن تتبع الشركة نفسها';
      end if;
    end if;
  elsif tg_table_name = 'erp_cashboxes' then
    if new.branch_id is not null then
      select company_id into v_company from public.erp_branches where id = new.branch_id;
      if v_company is distinct from new.company_id then
        raise exception 'فرع الخزينة يجب أن يتبع الشركة نفسها';
      end if;
    end if;
    if new.account_id is not null then
      select company_id, is_postable into v_company, v_postable
      from public.erp_accounts where id = new.account_id;
      if v_company is distinct from new.company_id or v_postable is distinct from true then
        raise exception 'حساب الخزينة يجب أن يكون حسابًا تحليليًا تابعًا للشركة نفسها';
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
  end if;
  return new;
end;
$$;

drop trigger if exists erp_warehouse_branch_guard on public.erp_warehouses;
create trigger erp_warehouse_branch_guard
before insert or update of company_id, branch_id on public.erp_warehouses
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_item_group_guard on public.erp_items;
create trigger erp_item_group_guard
before insert or update of company_id, group_id on public.erp_items
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

comment on function public.erp_validate_master_data_links() is
  'Prevents cross-company branch, item group, cashbox account, item unit and party contact links.';
