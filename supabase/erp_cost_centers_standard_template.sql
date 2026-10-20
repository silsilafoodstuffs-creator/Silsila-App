-- Atomic, company-scoped starter cost-center structure tailored to an Egyptian
-- wholesale/distribution business. This is an operational management template,
-- not a legally mandated chart prescribed by Egyptian Accounting Standards.
begin;

create or replace function public.erp_seed_standard_cost_centers(p_company_id uuid)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_count integer := 0;
  v_rows integer := 0;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً.';
  end if;

  if not public.erp_user_has_company_role(
    p_company_id, array['owner','admin','manager','accountant']::text[]
  ) then
    raise exception 'لا تملك صلاحية إنشاء مراكز التكلفة لهذه الشركة.';
  end if;

  -- Top-level centers.
  with seed(code, name) as (
    values
      ('100', 'الإدارة العامة'),
      ('200', 'المبيعات والتوزيع'),
      ('300', 'المشتريات'),
      ('400', 'المخازن'),
      ('500', 'النقل والأسطول'),
      ('600', 'التسويق والعروض'),
      ('700', 'خدمة العملاء'),
      ('800', 'الموارد البشرية'),
      ('900', 'الإدارة المالية'),
      ('1000', 'تقنية المعلومات'),
      ('1100', 'الجودة والرقابة')
  )
  insert into public.erp_cost_centers(company_id, center_code, center_name, is_active)
  select p_company_id, code, name, true from seed
  on conflict (company_id, center_code) do nothing;
  get diagnostics v_rows = row_count;
  v_count := v_count + v_rows;

  -- Child centers. Parent links are resolved from the company-scoped parent row.
  with seed(parent_code, code, name) as (
    values
      ('100','101','الإدارة التنفيذية'),
      ('100','102','الشؤون القانونية والإدارية'),
      ('200','201','مبيعات الجملة'),
      ('200','202','مبيعات نصف الجملة'),
      ('200','203','المبيعات الإلكترونية'),
      ('200','204','عمولات المندوبين'),
      ('300','301','شراء محلي'),
      ('300','302','التعاقدات والموردون'),
      ('400','401','المخزن الرئيسي'),
      ('400','402','مخازن الفروع'),
      ('400','403','التجهيز والتحميل'),
      ('500','501','سيارات التوزيع'),
      ('500','502','الصيانة والوقود'),
      ('500','503','الشحن الخارجي'),
      ('600','601','العروض والخصومات التسويقية'),
      ('600','602','الإعلانات'),
      ('700','701','الدعم والشكاوى'),
      ('700','702','خدمة ما بعد البيع'),
      ('800','801','التعيينات والتدريب'),
      ('800','802','الحضور والرواتب'),
      ('900','901','الحسابات العامة'),
      ('900','902','الخزائن والبنوك'),
      ('900','903','الضرائب والفواتير الإلكترونية'),
      ('1000','1001','الأنظمة والدعم الفني'),
      ('1100','1101','مراجعة المخزون'),
      ('1100','1102','مراجعة الجودة والصلاحية')
  )
  insert into public.erp_cost_centers(company_id, center_code, center_name, parent_id, is_active)
  select p_company_id, seed.code, seed.name, parent.id, true
  from seed
  join public.erp_cost_centers parent
    on parent.company_id = p_company_id and parent.center_code = seed.parent_code
  on conflict (company_id, center_code) do nothing;
  get diagnostics v_rows = row_count;
  v_count := v_count + v_rows;

  return v_count;
end;
$$;

grant execute on function public.erp_seed_standard_cost_centers(uuid) to authenticated;
commit;
