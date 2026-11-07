-- Remove only records explicitly created as demo/test placeholders.
-- Preserve all non-demo catalog records and non-demo sales representatives.
do $$
declare
  v_employee_ids uuid[];
  v_item_ids uuid[];
  v_test_customer_id uuid;
begin
  select coalesce(array_agg(id), array[]::uuid[]) into v_employee_ids
  from public.erp_employees
  where notes in (
    'بيانات أولية مؤقتة؛ الموبايل والرقم القومي وهميان للتعديل',
    'بيانات اختبار فقط'
  );

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

  delete from public.erp_users where employee_id = any(v_employee_ids) and auth_user_id is null;

  update public.erp_sales_representatives
     set employee_id = null, updated_at = now()
   where employee_id = any(v_employee_ids) and is_demo_data = false;
  delete from public.erp_sales_representatives
   where employee_id = any(v_employee_ids) and is_demo_data = true;
  delete from public.erp_employees where id = any(v_employee_ids);

  -- Remove the known sample customer and its empty draft documents/shortage requests.
  select id into v_test_customer_id
  from public.erp_parties
  where party_code = 'CUST-0001' and party_name = 'عايز وظيفة'
  limit 1;

  if v_test_customer_id is not null then
    delete from public.erp_customer_shortages where customer_id = v_test_customer_id;
    delete from public.erp_sales_documents
     where customer_id = v_test_customer_id
       and status = 'draft'
       and grand_total = 0
       and paid_total = 0;
    delete from public.erp_parties where id = v_test_customer_id;
  end if;

  -- Remove explicitly flagged sample parties; no posted documents reference them.
  delete from public.erp_parties where is_demo_data = true;

  -- Remove the three explicitly named sample campaigns; their campaign lines cascade.
  delete from public.erp_sales_campaigns
   where title in (
     'عرض تجريبي للعملاء - جهينة 235 مللي',
     'عرض الرواكد التجريبي - جهينة 235 مللي',
     'عرض الترويج التجريبي - جهينة 235 مللي'
   );

  -- Remove the eight explicitly flagged test products.
  select coalesce(array_agg(id), array[]::uuid[]) into v_item_ids
  from public.erp_items
  where is_demo_data = true and item_code like 'TSTITM%';

  delete from public.erp_item_warehouse_settings where item_id = any(v_item_ids);
  delete from public.erp_item_units where item_id = any(v_item_ids);
  delete from public.erp_items where id = any(v_item_ids);

  -- Remove the six Juhayna 235ml records only where the explicit SILSILA_TEST opening-stock marker exists.
  select coalesce(array_agg(i.id), array[]::uuid[]) into v_item_ids
  from public.erp_items i
  where i.item_code like 'JUH-235-%'
    and exists (
      select 1 from public.erp_inventory_movements m
      where m.item_id = i.id
        and m.notes like 'SILSILA_TEST_OPENING_STOCK_20261020:%'
    );

  delete from public.erp_inventory_movements
   where item_id = any(v_item_ids)
     and notes like 'SILSILA_TEST_OPENING_STOCK_20261020:%';
  delete from public.erp_item_warehouse_settings where item_id = any(v_item_ids);
  delete from public.erp_item_units where item_id = any(v_item_ids);
  delete from public.erp_items where id = any(v_item_ids);

  -- Remove the empty test-only category hierarchy from leaf to root.
  delete from public.erp_item_categories where category_code = 'TSTCAT03';
  delete from public.erp_item_categories where category_code = 'TSTCAT02';
  delete from public.erp_item_categories where category_code = 'TSTCAT01';
end
$$;
