begin;

create or replace function public.erp_studio_validate_payload()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $studio$
declare
  v_node jsonb;
  v_id text;
  v_type text;
  v_ids text[] := array[]::text[];
  v_binding jsonb;
  v_source text;
  v_field text;
  v_allowed text[];
  v_props_count integer;
begin
  if jsonb_typeof(new.design_json) is distinct from 'object'
     or coalesce(new.design_json->>'schemaVersion', '') not in ('1','2')
     or jsonb_typeof(new.design_json->'nodes') is distinct from 'array'
     or jsonb_array_length(new.design_json->'nodes') > 500 then
    raise exception 'مخطط تصميم سلسلة ستوديو غير صالح';
  end if;

  if jsonb_typeof(new.binding_json) is distinct from 'object' then
    raise exception 'تعريف ربط البيانات غير صالح';
  end if;

  for v_node in
    select value from jsonb_array_elements(new.design_json->'nodes') as nodes(value)
  loop
    v_id := v_node->>'id';
    v_type := v_node->>'type';
    select count(*)::integer into v_props_count
      from jsonb_object_keys(v_node->'props');

    if v_id is null or length(v_id) not between 1 and 100
       or v_type is null
       or v_type not in (
         'text','button','field','card','divider','spacer','grid','tree','table',
         'icon','image','chart','tabs','form','list','badge','progress','stat',
         'container','filter'
       )
       or jsonb_typeof(v_node->'props') is distinct from 'object'
       or v_props_count > 40 then
      raise exception 'مكون غير صالح داخل تصميم سلسلة ستوديو';
    end if;

    if v_id = any(v_ids) then
      raise exception 'معرّفات مكونات التصميم يجب أن تكون فريدة';
    end if;
    v_ids := array_append(v_ids, v_id);

    v_binding := v_node->'props'->'binding';
    if v_binding is not null and jsonb_typeof(v_binding) = 'object' then
      v_source := v_binding->>'source';
      v_field := v_binding->>'field';
      v_allowed := case v_source
        when 'items' then array['id','item_code','item_name','base_unit','sale_price','purchase_price','is_active','brand_name']
        when 'brands' then array['id','brand_code','brand_name','is_active','brand_group']
        when 'categories' then array['id','category_code','category_name','is_active','parent_id']
        when 'warehouses' then array['id','warehouse_code','warehouse_name','address','is_active']
        when 'sales_documents' then array['id','document_number','document_date','document_type','status','grand_total','paid_total']
        when 'purchase_documents' then array['id','document_number','document_date','document_type','status','grand_total','paid_total']
        when 'stock_balances' then array['warehouse_id','item_id','quantity_on_hand','today_quantity_in','today_quantity_out','inventory_value','average_unit_cost']
        else null
      end;
      if v_allowed is null or v_field is null or not (v_field = any(v_allowed)) then
        raise exception 'مصدر أو حقل ربط غير مسموح به في سلسلة ستوديو';
      end if;
    end if;
  end loop;

  if new.binding_json ? 'bindings' then
    if jsonb_typeof(new.binding_json->'bindings') is distinct from 'object' then
      raise exception 'قائمة ربط المكونات غير صالحة';
    end if;
    for v_id, v_binding in
      select key, value from jsonb_each(new.binding_json->'bindings')
    loop
      if not (v_id = any(v_ids)) or jsonb_typeof(v_binding) is distinct from 'object' then
        raise exception 'ربط يشير إلى مكون غير موجود';
      end if;
      v_source := v_binding->>'source';
      v_field := v_binding->>'field';
      v_allowed := case v_source
        when 'items' then array['id','item_code','item_name','base_unit','sale_price','purchase_price','is_active','brand_name']
        when 'brands' then array['id','brand_code','brand_name','is_active','brand_group']
        when 'categories' then array['id','category_code','category_name','is_active','parent_id']
        when 'warehouses' then array['id','warehouse_code','warehouse_name','address','is_active']
        when 'sales_documents' then array['id','document_number','document_date','document_type','status','grand_total','paid_total']
        when 'purchase_documents' then array['id','document_number','document_date','document_type','status','grand_total','paid_total']
        when 'stock_balances' then array['warehouse_id','item_id','quantity_on_hand','today_quantity_in','today_quantity_out','inventory_value','average_unit_cost']
        else null
      end;
      if v_allowed is null or v_field is null or not (v_field = any(v_allowed)) then
        raise exception 'مصدر أو حقل ربط غير مسموح به في سلسلة ستوديو';
      end if;
    end loop;
  end if;

  return new;
end;
$studio$;

commit;
