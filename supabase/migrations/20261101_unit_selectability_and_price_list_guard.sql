create or replace function public.erp_validate_item_unit_level()
returns trigger language plpgsql set search_path=public as $$
declare v_duplicate_count integer; v_invalid_duplicate_count integer;
begin
  if new.conversion_factor <= 0 then raise exception 'معامل تحويل الوحدة يجب أن يكون أكبر من صفر.'; end if;
  if new.unit_level is not null then
    if new.inner_quantity is not null and new.inner_quantity <= 0 then raise exception 'العدد الداخلي يجب أن يكون أكبر من صفر.'; end if;
    if new.is_implicit then
      new.is_selectable:=false;
    else
      select count(*),count(*) filter(where conversion_factor<>1) into v_duplicate_count,v_invalid_duplicate_count
      from public.erp_item_units u where u.item_id=new.item_id
        and lower(trim(u.unit_name))=lower(trim(new.unit_name))
        and u.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
        and u.is_active and not u.is_implicit;
      if v_duplicate_count>0 and (new.conversion_factor<>1 or v_invalid_duplicate_count>0) then
        raise exception 'تكرار اسم الوحدة يدويًا مسموح فقط عندما يكون معامل تحويل كل الوحدات المتكررة 1.';
      end if;
      if v_duplicate_count>0 then
        new.is_selectable:=false;
        update public.erp_item_units set is_selectable=false where item_id=new.item_id
          and lower(trim(unit_name))=lower(trim(new.unit_name)) and is_active and not is_implicit
          and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists erp_item_units_validate_level on public.erp_item_units;
create trigger erp_item_units_validate_level
before insert or update of item_id,unit_name,conversion_factor,unit_level,inner_quantity,is_implicit
on public.erp_item_units for each row execute function public.erp_validate_item_unit_level();

create or replace function public.erp_validate_price_list_item_unit_selectable()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.item_unit_id is not null and not exists (
    select 1 from public.erp_item_units u where u.id=new.item_unit_id
      and u.item_id=new.item_id and u.company_id=new.company_id and u.is_active and u.is_selectable
  ) then
    raise exception 'لا يمكن ربط قائمة الأسعار بوحدة مخفية أو غير نشطة أو لا تخص الصنف.';
  end if;
  return new;
end $$;
drop trigger if exists erp_price_list_unit_selectable_guard on public.erp_price_list_lines;
create trigger erp_price_list_unit_selectable_guard
before insert or update of item_id,item_unit_id,company_id on public.erp_price_list_lines
for each row execute function public.erp_validate_price_list_item_unit_selectable();
