-- Canonicalize ERP item classification permanently: categories only.
-- The existing category IDs were copied from the old catalog before this migration.
-- Keep the migration transactional so a failed dependency check rolls back safely.

do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.erp_validate_master_data_links()'::regprocedure);
  v_def := replace(v_def, 'erp_item_groups', 'erp_item_categories');
  v_def := replace(v_def, 'group_id', 'category_id');
  v_def := replace(v_def, 'group_code', 'category_code');
  v_def := replace(v_def, 'group_name', 'category_name');
  v_def := replace(v_def, 'المجموعة الأب', 'الفئة الأم');
  v_def := replace(v_def, 'مجموعة الصنف', 'فئة الصنف');
  v_def := replace(v_def, 'المجموعة', 'الفئة');
  execute v_def;

  v_def := pg_get_functiondef('public.erp_prevent_duplicate_item_group_names()'::regprocedure);
  v_def := replace(v_def, 'erp_prevent_duplicate_item_group_names', 'erp_prevent_duplicate_item_category_names');
  v_def := replace(v_def, 'erp_item_groups', 'erp_item_categories');
  v_def := replace(v_def, 'group_name', 'category_name');
  execute v_def;

  v_def := pg_get_functiondef('public.erp_prepare_selective_data_clear(uuid,text[])'::regprocedure);
  v_def := replace(v_def, 'erp_item_groups', 'erp_item_categories');
  execute v_def;

  v_def := pg_get_functiondef('public.erp_complete_selective_data_clear(uuid,text)'::regprocedure);
  v_def := replace(v_def, 'erp_item_groups', 'erp_item_categories');
  execute v_def;
end $$;

drop trigger if exists erp_item_group_guard on public.erp_items;
drop trigger if exists erp_item_group_parent_guard on public.erp_item_groups;
drop trigger if exists erp_item_groups_no_duplicate_names on public.erp_item_groups;

drop trigger if exists erp_item_category_parent_guard on public.erp_item_categories;
create trigger erp_item_category_parent_guard
before insert or update of company_id, parent_id on public.erp_item_categories
for each row execute function public.erp_validate_master_data_links();

drop trigger if exists erp_item_categories_no_duplicate_names on public.erp_item_categories;
create trigger erp_item_categories_no_duplicate_names
before insert or update of company_id, activity_code, category_name on public.erp_item_categories
for each row execute function public.erp_prevent_duplicate_item_category_names();

drop policy if exists erp_items_public_catalog_read on public.erp_items;
create policy erp_items_public_catalog_read on public.erp_items
for select to anon, authenticated
using (
  is_active = true and show_in_app = true
  and category_id is not null
  and exists (
    select 1 from public.erp_item_categories c
    where c.id = erp_items.category_id
      and c.company_id = erp_items.company_id
      and c.is_active = true
      and c.show_in_app = true
  )
);

drop policy if exists erp_item_categories_public_catalog_read on public.erp_item_categories;
create policy erp_item_categories_public_catalog_read on public.erp_item_categories
for select to anon, authenticated using (is_active = true and show_in_app = true);

alter table public.erp_items drop constraint if exists erp_items_group_id_fkey;
alter table public.erp_items drop column if exists group_id;
alter table public.erp_items drop constraint if exists erp_items_category_id_fkey;
alter table public.erp_items add constraint erp_items_category_id_fkey
  foreign key (category_id) references public.erp_item_categories(id) on delete restrict;
drop table public.erp_item_groups;
drop function if exists public.erp_prevent_duplicate_item_group_names();

drop trigger if exists erp_item_categories_item_guard on public.erp_items;
create trigger erp_item_categories_item_guard
before insert or update of company_id, category_id on public.erp_items
for each row execute function public.erp_validate_item_category_assignment();
