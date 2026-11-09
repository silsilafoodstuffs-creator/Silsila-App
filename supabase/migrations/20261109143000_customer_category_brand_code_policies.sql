-- Customer code: Cus + country/governorate/center/area (2 digits each) + 2-digit serial.
create or replace function public.erp_assign_customer_geo_code()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_geo_code text; v_prefix text := 'Cus'; v_digits integer := 2; v_policy text; v_max bigint; v_lock text;
begin
  if coalesce(new.party_kind, '') <> 'customer' then return new; end if;
  if tg_op = 'UPDATE' and new.geographic_area_id is not distinct from old.geographic_area_id then return new; end if;
  if new.geographic_area_id is null then raise exception 'اختيار المنطقة/القرية مطلوب لتوليد كود العميل'; end if;
  select hierarchical_code into v_geo_code from public.erp_geographic_data
   where id = new.geographic_area_id and company_id = new.company_id and level = 'area' and is_active = true;
  if v_geo_code is null or v_geo_code !~ '^[0-9]{8}$' then
    raise exception 'كود التقسيم الجغرافي يجب أن يتكون من الدولة والمحافظة والحي/المركز والمنطقة/القرية، خانتان لكل مستوى';
  end if;
  select policy_value into v_policy from public.erp_program_policies
   where company_id = new.company_id and policy_key = 'code_generation_registry' limit 1;
  if v_policy is not null and left(v_policy, 1) = '{' then
    v_prefix := coalesce(nullif(v_policy::jsonb #>> '{types,customer,prefix}', ''), 'Cus');
    v_digits := coalesce(nullif(v_policy::jsonb #>> '{types,customer,digits}', '')::integer, 2);
  end if;
  if v_prefix <> 'Cus' or v_digits <> 2 then raise exception 'سياسة كود العميل ثابتة على Cus وتسلسل من خانتين'; end if;
  v_lock := new.company_id::text || ':customer:' || new.geographic_area_id::text;
  perform pg_advisory_xact_lock(hashtextextended(v_lock, 0));
  select coalesce(max(substring(p.party_code from (length(v_prefix || v_geo_code) + 1))::bigint), 0) into v_max
  from public.erp_parties p
  where p.company_id = new.company_id and p.party_kind = 'customer'
    and p.geographic_area_id = new.geographic_area_id
    and p.party_code ~ ('^' || v_prefix || v_geo_code || '[0-9]{2}$')
    and (tg_op = 'INSERT' or p.id <> new.id);
  if coalesce(v_max, 0) >= 99 then raise exception 'اكتمل تسلسل العملاء المكون من خانتين داخل هذه المنطقة'; end if;
  new.party_code := v_prefix || v_geo_code || lpad((coalesce(v_max, 0) + 1)::text, 2, '0');
  return new;
end;
$$;

create or replace function public.erp_preview_next_customer_geo_code(p_company_id uuid, p_geo_area_id uuid)
returns text language plpgsql security definer set search_path = ''
as $$
declare v_geo_code text; v_max bigint;
begin
  if auth.uid() is null or not public.erp_user_can_access_company(p_company_id) then
    raise exception 'غير مصرح بمعاينة أكواد هذه الشركة';
  end if;
  select g.hierarchical_code into v_geo_code from public.erp_geographic_data g
   where g.id = p_geo_area_id and g.company_id = p_company_id and g.level = 'area' and g.is_active = true;
  if v_geo_code is null or v_geo_code !~ '^[0-9]{8}$' then
    raise exception 'اختر منطقة فعالة لها كود جغرافي من 8 أرقام (2 دولة + 2 محافظة + 2 حي/مركز + 2 منطقة/قرية)';
  end if;
  select coalesce(max(substring(p.party_code from 12)::bigint), 0) into v_max
  from public.erp_parties p
  where p.company_id = p_company_id and p.party_kind = 'customer'
    and p.geographic_area_id = p_geo_area_id
    and p.party_code ~ ('^Cus' || v_geo_code || '[0-9]{2}$');
  if v_max >= 99 then raise exception 'اكتمل تسلسل العملاء المكون من خانتين داخل هذه المنطقة'; end if;
  return 'Cus' || v_geo_code || lpad((v_max + 1)::text, 2, '0');
end;
$$;
revoke all on function public.erp_preview_next_customer_geo_code(uuid,uuid) from public, anon;
grant execute on function public.erp_preview_next_customer_geo_code(uuid,uuid) to authenticated;

-- Category codes: Cat + main(2) + sub(2) + secondary(2).
create or replace function public.erp_item_categories_validate_tree_and_code()
returns trigger language plpgsql set search_path = 'public'
as $function$
declare
  parent_company uuid; parent_activity text; v_parent_id uuid; v_node record;
  v_rank integer; v_level integer := 1; v_path text[] := array[]::text[]; v_prefix text := 'Cat';
begin
  if new.parent_id is not null then
    select p.company_id, p.activity_code into parent_company, parent_activity
    from public.erp_item_categories p where p.id = new.parent_id;
    if not found then raise exception 'الفئة الرئيسية المحددة غير موجودة.'; end if;
    if parent_company is distinct from new.company_id or parent_activity is distinct from new.activity_code then
      raise exception 'يجب أن تنتمي الفئة وأصلها إلى الشركة والنشاط نفسيهما.';
    end if;
    if new.parent_id = new.id then raise exception 'لا يمكن أن تكون الفئة أصلًا لنفسها.'; end if;
  end if;

  if new.category_code is null or btrim(new.category_code) = '' then
    v_parent_id := new.parent_id;
    while v_parent_id is not null loop
      select id, parent_id, category_code, company_id, activity_code into v_node
      from public.erp_item_categories where id = v_parent_id;
      if not found then raise exception 'تعذر قراءة تسلسل الفئات الأعلى.'; end if;
      if v_node.company_id is distinct from new.company_id or v_node.activity_code is distinct from new.activity_code then
        raise exception 'يجب أن تنتمي الفئة وأصلها إلى الشركة والنشاط نفسيهما.';
      end if;
      select count(*) into v_rank from public.erp_item_categories c
      where c.company_id = new.company_id and c.activity_code is not distinct from new.activity_code
        and c.parent_id is not distinct from v_node.parent_id
        and (c.category_code, c.id) <= (v_node.category_code, v_node.id);
      if v_rank < 1 or v_rank > 99 then raise exception 'عدد الفئات في المستوى يتجاوز 99؛ راجع سياسة Cat.'; end if;
      v_path := array_prepend(lpad(v_rank::text, 2, '0'), v_path);
      v_parent_id := v_node.parent_id; v_level := v_level + 1;
      if v_level > 3 then raise exception 'يسمح بثلاثة مستويات فقط: رئيسية وفرعية وثانوية.'; end if;
    end loop;
    select count(*) + 1 into v_rank from public.erp_item_categories c
    where c.company_id = new.company_id and c.activity_code is not distinct from new.activity_code
      and c.parent_id is not distinct from new.parent_id;
    if v_rank > 99 then raise exception 'عدد الفئات في المستوى يتجاوز 99؛ راجع سياسة Cat.'; end if;
    new.category_code := v_prefix || array_to_string(v_path, '') || lpad(v_rank::text, 2, '0');
  elsif (tg_op = 'INSERT' or new.category_code is distinct from old.category_code)
        and new.category_code !~ '^[A-Za-z]+[A-Za-z0-9]*$' then
    raise exception 'كود الفئة يجب أن يتكون من حروف إنجليزية وأرقام فقط.';
  end if;
  return new;
end;
$function$;

-- Store the independent Cus, Cat and Bra settings while retaining every other policy.
update public.erp_program_policies p
set policy_value = (
  jsonb_set(
    jsonb_set(
      jsonb_set(
        case when left(p.policy_value, 1) = '{' then p.policy_value::jsonb else '{}'::jsonb end,
        '{types}',
        coalesce((case when left(p.policy_value, 1) = '{' then p.policy_value::jsonb else '{}'::jsonb end)->'types', '{}'::jsonb)
        || jsonb_build_object(
          'customer', jsonb_build_object('prefix','Cus','digits',2,'automatic',true,'composite',true,'required',true,'apply_to_all',true,
            'fields',jsonb_build_array(jsonb_build_object('name','تسلسل العميل','digits',2),
              jsonb_build_object('name','المنطقة/القرية','digits',2),jsonb_build_object('name','الحي/المركز','digits',2),
              jsonb_build_object('name','المحافظة','digits',2))),
          'category', jsonb_build_object('prefix','Cat','digits',6,'automatic',true,'composite',true,
            'fields',jsonb_build_array(jsonb_build_object('name','تسلسل الفئة الثانوية','digits',2),
              jsonb_build_object('name','الفئة الفرعية','digits',2),jsonb_build_object('name','الفئة الرئيسية','digits',2))),
          'brand', jsonb_build_object('prefix','Bra','digits',3,'automatic',true,'composite',false)
        ), true
      ),
      '{category_prefix}','"Cat"'::jsonb,true
    ),
    '{category_segments}','{"main":2,"sub":2,"secondary":2}'::jsonb,true
  ) || jsonb_build_object('brand_prefix','Bra','brand_digits',3)
)::text,
updated_at = now()
where p.policy_key = 'code_generation_registry';
