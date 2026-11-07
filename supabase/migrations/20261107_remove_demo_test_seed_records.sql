-- Remove only records that were explicitly created as demo/test placeholders.
-- Preserve actual catalog items, companies, accounts, and non-demo sales representatives.
do $$
declare
  v_employee_ids uuid[];
  v_item_ids uuid[];
begin
  select coalesce(array_agg(id), array[]::uuid[])
    into v_employee_ids
  from public.erp_employees
  where notes in (
    'بيانات أولية مؤقتة؛ الموبايل والرقم القومي وهميان للتعديل',
    'بيانات اختبار فقط'
  );

  -- Remove dependent HR records attached only to those explicit placeholder employees.
  delete from public.erp_attendance_records where employee_id = any(v_employee_ids);
  delete from public.erp_hr_attendance_events where employee_id = any(v_employee_ids);
  delete from public.erp_delegate_item_assignments where employee_id = any(v_employee_ids);
  delete from public.erp_employee_documents where employee_id = any(v_employee_ids);
  delete from public.erp_employee_monthly_targets where employee_id = any(v_employee_ids);
  delete from public.erp_hr_employee_actions where employee_id = any(v_employee_ids);
  delete from public.erp_hr_employee_advances where employee_id = any(v_employee_ids);
  delete from public.erp_hr_employee_compliance where employee_id = any(v_employee_ids);
  delete from public.erp_hr_employee_contracts where employee_id = any(v_employee_ids);
  delete from public.erp_hr_employee_custodies where employee_id = any(v_employee_ids);
  delete from public.erp_hr_employee_movements where employee_id = any(v_employee_ids);
  delete from public.erp_hr_end_of_service_settlements where employee_id = any(v_employee_ids);
  delete from public.erp_hr_overtime_requests where employee_id = any(v_employee_ids);
  delete from public.erp_hr_performance_reviews where employee_id = any(v_employee_ids);
  delete from public.erp_hr_shift_assignments where employee_id = any(v_employee_ids);
  delete from public.erp_hr_training_records where employee_id = any(v_employee_ids);
  delete from public.erp_leave_requests where employee_id = any(v_employee_ids);
  delete from public.erp_payroll_lines where employee_id = any(v_employee_ids);

  -- These 17 ERP user-directory rows had no linked Supabase Auth user.
  delete from public.erp_users
  where employee_id = any(v_employee_ids)
    and auth_user_id is null;

  -- Preserve non-demo rep records, but detach their links to placeholder employees.
  update public.erp_sales_representatives
     set employee_id = null, updated_at = now()
   where employee_id = any(v_employee_ids)
     and is_demo_data = false;

  delete from public.erp_sales_representatives
   where employee_id = any(v_employee_ids)
     and is_demo_data = true;

  delete from public.erp_employees where id = any(v_employee_ids);

  -- Remove explicitly flagged demo parties only; preflight found no dependent business documents.
  delete from public.erp_parties
   where is_demo_data = true
     and party_code like 'DEMO-%';

  -- Remove the three explicitly named sample campaigns; their campaign lines cascade.
  delete from public.erp_sales_campaigns
   where title in (
     'عرض تجريبي للعملاء - جهينة 235 مللي',
     'عرض الرواكد التجريبي - جهينة 235 مللي',
     'عرض الترويج التجريبي - جهينة 235 مللي'
   );

  -- Remove only the eight explicitly flagged TSTITM test products and their generated settings/units.
  select coalesce(array_agg(id), array[]::uuid[])
    into v_item_ids
  from public.erp_items
  where is_demo_data = true
    and item_code like 'TSTITM%';

  delete from public.erp_item_warehouse_settings where item_id = any(v_item_ids);
  delete from public.erp_item_units where item_id = any(v_item_ids);
  delete from public.erp_items where id = any(v_item_ids);

  -- Remove the empty test-only category hierarchy from leaf to root.
  delete from public.erp_item_categories where category_code = 'TSTCAT03';
  delete from public.erp_item_categories where category_code = 'TSTCAT02';
  delete from public.erp_item_categories where category_code = 'TSTCAT01';
end
$$;
