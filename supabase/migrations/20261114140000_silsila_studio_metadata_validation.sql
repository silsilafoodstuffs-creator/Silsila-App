begin;

-- Validate document-level metadata independently of the Flutter client.
-- Imported Studio JSON is presentation data and must remain bounded data only.
create or replace function public.erp_studio_validate_document_metadata()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $studio$
declare
  v_bindings jsonb;
  v_rpc_bindings jsonb;
  v_settings jsonb;
  v_node jsonb;
  v_binding jsonb;
  v_count integer;
begin
  if jsonb_typeof(new.design_json) is distinct from 'object'
     or octet_length(new.design_json::text) > 1048576 then
    raise exception 'حجم أو بنية مستند سلسلة ستوديو غير صالح';
  end if;

  if jsonb_typeof(new.binding_json) is distinct from 'object'
     or octet_length(new.binding_json::text) > 262144 then
    raise exception 'حجم أو بنية تعريفات الربط المركزية غير صالحة';
  end if;

  v_rpc_bindings := new.binding_json->'bindings';
  if v_rpc_bindings is not null then
    if jsonb_typeof(v_rpc_bindings) is distinct from 'object' then
      raise exception 'قائمة الربط المركزية غير صالحة';
    end if;
    select count(*)::integer into v_count from jsonb_object_keys(v_rpc_bindings);
    if v_count > 500 then
      raise exception 'عدد تعريفات الربط المركزية تجاوز الحد المسموح';
    end if;
    for v_binding in select value from jsonb_each(v_rpc_bindings)
    loop
      if jsonb_typeof(v_binding) is distinct from 'object' then
        raise exception 'كل تعريف ربط مركزي يجب أن يكون كائن بيانات';
      end if;
    end loop;
  end if;

  v_bindings := new.design_json->'bindings';
  if v_bindings is not null then
    if jsonb_typeof(v_bindings) is distinct from 'object' then
      raise exception 'تعريفات الربط داخل مستند التصميم غير صالحة';
    end if;
    select count(*)::integer into v_count from jsonb_object_keys(v_bindings);
    if v_count > 500 then
      raise exception 'عدد تعريفات الربط داخل التصميم تجاوز الحد المسموح';
    end if;
    for v_binding in select value from jsonb_each(v_bindings)
    loop
      if jsonb_typeof(v_binding) is distinct from 'object' then
        raise exception 'كل تعريف ربط يجب أن يكون كائن بيانات';
      end if;
    end loop;
  end if;

  v_settings := new.design_json->'settings';
  if v_settings is not null then
    if jsonb_typeof(v_settings) is distinct from 'object' then
      raise exception 'إعدادات مستند التصميم غير صالحة';
    end if;
    select count(*)::integer into v_count from jsonb_object_keys(v_settings);
    if v_count > 80 then
      raise exception 'عدد إعدادات التصميم تجاوز الحد المسموح';
    end if;
  end if;

  for v_node in
    select value from jsonb_array_elements(new.design_json->'nodes') as nodes(value)
  loop
    if jsonb_typeof(v_node->'props') is distinct from 'object' then
      raise exception 'خصائص المكون داخل التصميم غير صالحة';
    end if;
    if (v_node->'props') ? 'binding'
       and jsonb_typeof(v_node->'props'->'binding') is distinct from 'object' then
      raise exception 'تعريف ربط المكون يجب أن يكون كائن بيانات';
    end if;
  end loop;

  return new;
end;
$studio$;

drop trigger if exists erp_studio_designs_validate_metadata
  on public.erp_studio_designs;
create trigger erp_studio_designs_validate_metadata
before insert or update of design_json, binding_json
on public.erp_studio_designs
for each row execute function public.erp_studio_validate_document_metadata();

drop trigger if exists erp_studio_versions_validate_metadata
  on public.erp_studio_design_versions;
create trigger erp_studio_versions_validate_metadata
before insert or update of design_json, binding_json
on public.erp_studio_design_versions
for each row execute function public.erp_studio_validate_document_metadata();

revoke all on function public.erp_studio_validate_document_metadata()
  from public, anon, authenticated;

commit;
