-- Enforce unique three-letter code namespaces across all configured entity types and item codes.
begin;
create or replace function public.erp_code_policy_config(
  p_company_id uuid, p_key text, p_default_prefix text, p_default_digits integer
)
returns table(prefix text, digits integer)
language plpgsql stable security definer set search_path = '' as $$
declare v jsonb; v_cfg jsonb;
begin
  select case when left(policy_value, 1) = '{' then policy_value::jsonb else '{}'::jsonb end
    into v
  from public.erp_program_policies
  where company_id = p_company_id and policy_key = 'code_generation_registry'
  limit 1;
  v_cfg := coalesce(v->'types'->p_key, '{}'::jsonb);
  prefix := coalesce(nullif(v_cfg->>'prefix', ''), p_default_prefix);
  digits := coalesce(nullif(v_cfg->>'digits', '')::integer, p_default_digits);
  if prefix !~ '^[A-Za-z]{3}$' or digits < 1 or digits > 12 then
    raise exception 'إعدادات التكويد غير صحيحة للنوع %', p_key;
  end if;
  if exists (
    select 1 from jsonb_each(coalesce(v->'types', '{}'::jsonb)) as configured(key, value)
    where configured.key <> p_key
      and lower(coalesce(configured.value->>'prefix', '')) = lower(prefix)
  ) then
    raise exception 'بادئة التكويد % مستخدمة بالفعل في نوع تكويد آخر', prefix;
  end if;
  if lower(coalesce(v->>'item_prefix', 'itm')) = lower(prefix) then
    raise exception 'بادئة التكويد % محجوزة للأصناف', prefix;
  end if;
  return next;
end;
$$;
revoke all on function public.erp_code_policy_config(uuid,text,text,integer) from public, anon, authenticated;

create or replace function public.erp_assign_item_hierarchical_code()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_prefix text;
  v_path text[] := array[]::text[];
  v_node record;
  v_parent uuid;
  v_rank integer;
  v_serial integer;
  v_lock text;
begin
  if nullif(new.item_code, '') is not null then return new; end if;
  if new.category_id is null then
    raise exception 'اختر الفئة الثانوية قبل حفظ الصنف لتوليد كوده';
  end if;

  select coalesce(
    nullif(
      (case when left(policy_value, 1) = '{' then policy_value::jsonb else '{}'::jsonb end)->>'item_prefix',
      ''
    ),
    'itm'
  ) into v_prefix
  from public.erp_program_policies
  where company_id = new.company_id and policy_key = 'code_generation_registry'
  limit 1;
  v_prefix := coalesce(v_prefix, 'itm');
  if v_prefix !~ '^[A-Za-z]{3}$' then
    raise exception 'بادئة كود الأصناف يجب أن تكون ثلاثة أحرف إنجليزية';
  end if;
  if exists (
    select 1
    from public.erp_program_policies p,
         jsonb_each(coalesce((case when left(p.policy_value, 1) = '{' then p.policy_value::jsonb else '{}'::jsonb end)->'types', '{}'::jsonb)) configured
    where p.company_id = new.company_id
      and p.policy_key = 'code_generation_registry'
      and lower(coalesce(configured.value->>'prefix', '')) = lower(v_prefix)
  ) then
    raise exception 'بادئة الأصناف مستخدمة بالفعل في نوع تكويد آخر';
  end if;

  v_parent := new.category_id;
  for i in 1..3 loop
    select id, parent_id, category_code into v_node
    from public.erp_item_categories
    where id = v_parent and company_id = new.company_id and is_active = true;
    if not found then raise exception 'الفئة المختارة غير موجودة أو غير نشطة'; end if;

    select count(*) into v_rank
    from public.erp_item_categories c
    where c.company_id = new.company_id
      and c.parent_id is not distinct from v_node.parent_id
      and c.is_active = true
      and c.activity_code is not distinct from (
        select activity_code from public.erp_item_categories where id = new.category_id
      )
      and (c.category_code, c.id) <= (v_node.category_code, v_node.id);

    if v_rank < 1 or v_rank > 99 then
      raise exception 'عدد الفئات في كل مستوى يجب ألا يتجاوز 99 لتكوين كود الصنف';
    end if;
    v_path := array_prepend(lpad(v_rank::text, 2, '0'), v_path);
    v_parent := v_node.parent_id;
    if i < 3 and v_parent is null then
      raise exception 'يجب اختيار فئة ثانوية مرتبطة بفئة رئيسية وفرعية';
    end if;
    if i = 3 and v_parent is not null then
      raise exception 'مستويات فئات الأصناف يجب ألا تتجاوز ثلاثة مستويات';
    end if;
  end loop;

  v_lock := new.company_id::text || ':item:' || v_prefix || array_to_string(v_path, '');
  perform pg_advisory_xact_lock(hashtextextended(v_lock, 0));

  select coalesce(max(right(item_code, 2)::integer), 0) into v_serial
  from public.erp_items
  where company_id = new.company_id
    and item_code ~ ('^' || v_prefix || array_to_string(v_path, '') || '[0-9]{2}$');

  if v_serial >= 99 then
    raise exception 'تم الوصول إلى الحد الأقصى 99 صنفًا داخل هذه الفئات';
  end if;
  new.item_code := v_prefix || array_to_string(v_path, '') ||
    lpad((coalesce(v_serial, 0) + 1)::text, 2, '0');
  return new;
end;
$$;
revoke all on function public.erp_assign_item_hierarchical_code() from public, anon, authenticated;
commit;
