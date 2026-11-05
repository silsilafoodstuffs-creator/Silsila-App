begin;

create or replace function public.erp_assign_item_hierarchical_code()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_policy jsonb := '{}'::jsonb;
  v_segments jsonb := '{}'::jsonb;
  v_prefix text := 'itm';
  v_main_digits integer := 2;
  v_sub_digits integer := 2;
  v_secondary_digits integer := 2;
  v_serial_digits integer := 2;
  v_path text[] := array[]::text[];
  v_node record;
  v_parent uuid;
  v_rank integer;
  v_max_rank numeric;
  v_serial integer;
  v_serial_max numeric;
  v_lock text;
  i integer;
begin
  if nullif(new.item_code, '') is not null then return new; end if;
  if new.category_id is null then
    raise exception 'اختر الفئة الثانوية قبل حفظ الصنف لتوليد كوده';
  end if;

  select case when left(policy_value, 1) = '{' then policy_value::jsonb else '{}'::jsonb end
    into v_policy
  from public.erp_program_policies
  where company_id = new.company_id and policy_key = 'code_generation_registry'
  limit 1;

  v_prefix := coalesce(nullif(v_policy->>'item_prefix', ''), 'itm');
  v_segments := coalesce(v_policy->'item_segments', '{}'::jsonb);
  v_main_digits := coalesce(nullif(v_segments->>'main', '')::integer, 2);
  v_sub_digits := coalesce(nullif(v_segments->>'sub', '')::integer, 2);
  v_secondary_digits := coalesce(nullif(v_segments->>'secondary', '')::integer, 2);
  v_serial_digits := coalesce(nullif(v_segments->>'serial', '')::integer, 2);

  if v_prefix !~ '^[A-Za-z]{3}$' then
    raise exception 'بادئة كود الأصناف يجب أن تكون ثلاثة أحرف إنجليزية';
  end if;
  if v_main_digits not between 1 and 4
     or v_sub_digits not between 1 and 4
     or v_secondary_digits not between 1 and 4
     or v_serial_digits not between 1 and 8 then
    raise exception 'أطوال خانات كود الأصناف غير صحيحة';
  end if;

  if exists (
    select 1
    from jsonb_each(coalesce(v_policy->'types', '{}'::jsonb)) configured
    where lower(coalesce(configured.value->>'prefix', '')) = lower(v_prefix)
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

    v_max_rank := case i
      when 1 then power(10::numeric, v_secondary_digits) - 1
      when 2 then power(10::numeric, v_sub_digits) - 1
      else power(10::numeric, v_main_digits) - 1
    end;
    if v_rank < 1 or v_rank > v_max_rank then
      raise exception 'عدد الفئات في المستوى % تجاوز سعة الكود المحددة (% خانات)', 4-i,
        case i when 1 then v_secondary_digits when 2 then v_sub_digits else v_main_digits end;
    end if;

    v_path := array_prepend(
      lpad(v_rank::text, case i when 1 then v_secondary_digits when 2 then v_sub_digits else v_main_digits end, '0'),
      v_path
    );
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

  v_serial_max := power(10::numeric, v_serial_digits) - 1;
  execute format(
    'select coalesce(max(right(item_code, %s)::integer), 0) from public.erp_items where company_id = $1 and item_code ~ $2',
    v_serial_digits
  ) into v_serial
  using new.company_id,
    '^' || v_prefix || array_to_string(v_path, '') || '[0-9]{' || v_serial_digits || '}$';

  if coalesce(v_serial, 0) >= v_serial_max then
    raise exception 'تم الوصول إلى الحد الأقصى للتسلسل داخل هذه الفئات؛ زد عدد خانات التسلسل';
  end if;

  new.item_code := v_prefix || array_to_string(v_path, '') ||
    lpad((coalesce(v_serial, 0) + 1)::text, v_serial_digits, '0');
  return new;
end;
$function$;

revoke all on function public.erp_assign_item_hierarchical_code() from public, anon, authenticated;

commit;