alter table public.erp_item_units
  add column if not exists unit_level smallint,
  add column if not exists inner_quantity numeric(14,6),
  add column if not exists is_implicit boolean not null default false,
  add column if not exists is_selectable boolean not null default true;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid='public.erp_item_units'::regclass and conname='erp_item_units_unit_level_check') then
    alter table public.erp_item_units add constraint erp_item_units_unit_level_check check (unit_level is null or unit_level in (1,2,3));
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.erp_item_units'::regclass and conname='erp_item_units_inner_quantity_check') then
    alter table public.erp_item_units add constraint erp_item_units_inner_quantity_check check (inner_quantity is null or inner_quantity > 0);
  end if;
end $$;

create unique index if not exists erp_item_units_item_level_idx on public.erp_item_units(item_id,unit_level) where unit_level is not null;

create or replace function public.erp_validate_item_unit_level()
returns trigger language plpgsql set search_path=public as $$
declare v_duplicate_count integer; v_invalid_duplicate_count integer;
begin
  if new.conversion_factor <= 0 then raise exception 'معامل تحويل الوحدة يجب أن يكون أكبر من صفر.'; end if;
  if new.unit_level is not null then
    if new.inner_quantity is not null and new.inner_quantity <= 0 then raise exception 'العدد الداخلي يجب أن يكون أكبر من صفر.'; end if;
    select count(*),count(*) filter(where conversion_factor<>1) into v_duplicate_count,v_invalid_duplicate_count
    from public.erp_item_units u where u.item_id=new.item_id
      and lower(trim(u.unit_name))=lower(trim(new.unit_name))
      and u.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid) and u.is_active;
    if v_duplicate_count>0 and (new.conversion_factor<>1 or v_invalid_duplicate_count>0) then
      raise exception 'تكرار اسم الوحدة مسموح فقط عندما يكون معامل تحويل كل الوحدات المتكررة 1.';
    end if;
    if v_duplicate_count>0 then
      new.is_selectable:=false;
      update public.erp_item_units set is_selectable=false where item_id=new.item_id
        and lower(trim(unit_name))=lower(trim(new.unit_name)) and is_active
        and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists erp_item_units_validate_level on public.erp_item_units;
create trigger erp_item_units_validate_level
before insert or update of item_id,unit_name,conversion_factor,unit_level,inner_quantity
on public.erp_item_units for each row execute function public.erp_validate_item_unit_level();

comment on column public.erp_item_units.unit_level is '1=major, 2=middle, 3=minor; NULL preserves legacy unit semantics';
comment on column public.erp_item_units.inner_quantity is 'Number of next-lower units contained in this unit';
comment on column public.erp_item_units.is_implicit is 'Automatically synthesized middle unit when skipped';
comment on column public.erp_item_units.is_selectable is 'False for repeated-name factor-one units; hidden from pickers';
