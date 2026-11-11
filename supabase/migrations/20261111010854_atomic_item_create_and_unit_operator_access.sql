-- Atomic item master creation and unit permissions for the same operational roles as erp_items.
drop policy if exists erp_item_units_company_admin_all on public.erp_item_units;

create policy erp_item_units_company_operator_access
on public.erp_item_units
for all
to authenticated
using (
  public.erp_user_has_company_role(
    company_id,
    array['owner','admin','manager','operator','accountant']::text[]
  )
)
with check (
  public.erp_user_has_company_role(
    company_id,
    array['owner','admin','manager','operator','accountant']::text[]
  )
);

create or replace function public.erp_create_item_with_units(
  p_item jsonb,
  p_units jsonb
)
returns table(id uuid, item_code text)
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
declare
  v_company_id uuid;
  v_item_id uuid;
  v_item_code text;
  v_image_hex text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if jsonb_typeof(p_item) <> 'object' or jsonb_typeof(p_units) <> 'array' then
    raise exception 'Invalid item payload or units array' using errcode = '22023';
  end if;
  v_company_id := nullif(p_item->>'company_id','')::uuid;
  if v_company_id is null then
    raise exception 'Company is required' using errcode = '22023';
  end if;
  if not public.erp_user_has_company_role(
    v_company_id,
    array['owner','admin','manager','operator','accountant']::text[]
  ) then
    raise exception 'Insufficient company role to create items' using errcode = '42501';
  end if;
  if nullif(btrim(p_item->>'item_name'),'') is null then
    raise exception 'Item name is required' using errcode = '22023';
  end if;
  if nullif(p_item->>'category_id','') is null then
    raise exception 'Item category is required' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.erp_item_categories c
    where c.id = (p_item->>'category_id')::uuid
      and c.company_id = v_company_id and c.is_active = true
  ) then
    raise exception 'Selected category is unavailable for this company' using errcode = '23503';
  end if;
  if nullif(p_item->>'brand_id','') is not null and not exists (
    select 1 from public.erp_brands b
    where b.id = (p_item->>'brand_id')::uuid
      and b.company_id = v_company_id and b.is_active = true
  ) then
    raise exception 'Selected brand is unavailable for this company' using errcode = '23503';
  end if;
  if jsonb_array_length(p_units) < 1 or jsonb_array_length(p_units) > 3 then
    raise exception 'An item must define between one and three unit levels' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_to_recordset(p_units) as u(
      unit_level smallint, unit_name text, conversion_factor numeric
    )
    where u.unit_level not between 1 and 3
       or nullif(btrim(u.unit_name),'') is null
       or u.conversion_factor is null or u.conversion_factor <= 0
  ) then
    raise exception 'Invalid item unit definition' using errcode = '22023';
  end if;
  if (select count(distinct x.unit_level)
      from jsonb_to_recordset(p_units) as x(unit_level smallint))
     <> jsonb_array_length(p_units) then
    raise exception 'Duplicate unit level' using errcode = '22023';
  end if;
  v_image_hex := nullif(p_item->>'image_data','');
  insert into public.erp_items (
    company_id, item_code, item_name, item_name_en, category_id, brand_id,
    barcode, base_unit, purchase_price, sale_price, tax_rate, reorder_level,
    expiry_tracking, image_data, image_mime_type, image_url, is_active
  ) values (
    v_company_id, '', btrim(p_item->>'item_name'),
    coalesce(p_item->>'item_name_en',''),
    (p_item->>'category_id')::uuid,
    nullif(p_item->>'brand_id','')::uuid,
    nullif(btrim(p_item->>'barcode'),''),
    coalesce(nullif(btrim(p_item->>'base_unit'),''),'وحدة'),
    coalesce(nullif(p_item->>'purchase_price','')::numeric,0),
    coalesce(nullif(p_item->>'sale_price','')::numeric,0),
    coalesce(nullif(p_item->>'tax_rate','')::numeric,0),
    coalesce(nullif(p_item->>'reorder_level','')::numeric,0),
    coalesce((p_item->>'expiry_tracking')::boolean,false),
    case when v_image_hex is null then null
         else decode(replace(v_image_hex, E'\\x',''),'hex') end,
    nullif(p_item->>'image_mime_type',''), null, true
  )
  returning erp_items.id, erp_items.item_code into v_item_id, v_item_code;
  insert into public.erp_item_units (
    company_id, item_id, unit_code, unit_name, conversion_factor,
    is_base_unit, is_active, unit_level, inner_quantity, is_implicit, is_selectable
  )
  select v_company_id, v_item_id, u.unit_code, btrim(u.unit_name),
         u.conversion_factor, coalesce(u.is_base_unit,false), true,
         u.unit_level, u.inner_quantity, coalesce(u.is_implicit,false),
         coalesce(u.is_selectable,true)
  from jsonb_to_recordset(p_units) as u(
    unit_code text, unit_name text, conversion_factor numeric,
    is_base_unit boolean, unit_level smallint, inner_quantity numeric,
    is_implicit boolean, is_selectable boolean
  );
  return query select v_item_id, v_item_code;
end;
$function$;

revoke all on function public.erp_create_item_with_units(jsonb,jsonb) from public;
revoke all on function public.erp_create_item_with_units(jsonb,jsonb) from anon;
grant execute on function public.erp_create_item_with_units(jsonb,jsonb) to authenticated;
