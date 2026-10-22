-- Transactional preparation and completion for screen-based ERP data clearing.
-- Run after 20261022_erp_data_backups.sql and erp_workspace_records.sql.
begin;

create or replace function public.erp_prepare_selective_data_clear(
  p_company_id uuid,
  p_selected_pages text[]
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_pages text[];
  v_tables text[];
  v_table text;
  v_rows jsonb;
  v_sales_types text[];
  v_purchase_types text[];
  v_price_kinds text[];
  v_party_kinds text[];
  v_movement_types text[];
  v_asset_types text[];
  v_voucher_types text[];
  v_has_customer boolean;
  v_has_supplier boolean;
  v_payload jsonb := jsonb_build_object(
    'format', 'silsila-selective-backup-v2',
    'created_at', to_jsonb(clock_timestamp()),
    'company_id', p_company_id,
    'selected_pages', coalesce(to_jsonb(p_selected_pages), '[]'::jsonb),
    'tables', '{}'::jsonb
  );
  v_total integer := 0;
  v_backup_id text;
begin
  if v_user is null then raise exception 'يجب تسجيل الدخول أولاً.'; end if;
  if p_company_id is null then raise exception 'يجب تحديد الشركة.'; end if;
  if not public.erp_user_has_company_role(p_company_id, array['owner','admin']::text[]) then
    raise exception 'هذه العملية متاحة لمالك الشركة أو مديرها فقط.';
  end if;

  select array_agg(distinct trim(p)) into v_pages
  from unnest(coalesce(p_selected_pages, '{}'::text[])) as u(p)
  where trim(p) <> '';
  if coalesce(array_length(v_pages, 1), 0) = 0 then
    raise exception 'حدد شاشة واحدة على الأقل.';
  end if;

  select coalesce(array_agg(distinct case p when 'عرض سعر' then 'quotation' when 'أمر بيع' then 'order' when 'فاتورة بيع' then 'invoice' when 'فاتورة مبيعات' then 'invoice' when 'مرتجع مبيعات' then 'return' end) filter (where p in ('عرض سعر','أمر بيع','فاتورة بيع','فاتورة مبيعات','مرتجع مبيعات')), '{}'::text[]) into v_sales_types from unnest(v_pages) p;
  select coalesce(array_agg(distinct case p when 'أمر شراء' then 'order' when 'استلام مشتريات' then 'receipt' when 'فاتورة مشتريات' then 'invoice' when 'مرتجع مشتريات' then 'return' end) filter (where p in ('أمر شراء','استلام مشتريات','فاتورة مشتريات','مرتجع مشتريات')), '{}'::text[]) into v_purchase_types from unnest(v_pages) p;
  select coalesce(array_agg(distinct case p when 'قوائم أسعار البيع' then 'sale' when 'قوائم أسعار الموردين' then 'purchase' when 'سياسات التسعير والخصومات' then 'sale' end) filter (where p in ('قوائم أسعار البيع','قوائم أسعار الموردين','سياسات التسعير والخصومات')), '{}'::text[]) into v_price_kinds from unnest(v_pages) p;
  if 'سياسات التسعير والخصومات' = any(v_pages) then v_price_kinds := array['sale','purchase']::text[]; end if;
  v_has_customer := 'دليل العملاء' = any(v_pages);
  v_has_supplier := 'دليل الموردين' = any(v_pages);
  if v_has_customer and v_has_supplier then v_party_kinds := array['customer','supplier','both']::text[];
  elsif v_has_customer then v_party_kinds := array['customer']::text[];
  elsif v_has_supplier then v_party_kinds := array['supplier']::text[];
  else v_party_kinds := '{}'::text[]; end if;
  select coalesce(array_agg(distinct case p when 'إذن إضافة' then 'purchase_receipt' when 'إذن صرف' then 'sales_issue' when 'تحويل مخزني' then 'transfer_in' when 'تسوية جرد' then 'adjustment' when 'جرد فعلي' then 'adjustment' end) filter (where p in ('إذن إضافة','إذن صرف','تحويل مخزني','تسوية جرد','جرد فعلي')), '{}'::text[]) into v_movement_types from unnest(v_pages) p;
  if 'تحويل مخزني'=any(v_pages) then v_movement_types := array_append(v_movement_types,'transfer_out'); end if;
  if 'إذن صرف'=any(v_pages) then v_movement_types := array_append(v_movement_types,'waste'); end if;
  select coalesce(array_agg(distinct case p when 'إدارة الشعار والصور' then 'app_logo' when 'إدارة صور الأصناف والفئات' then 'item' when 'إدارة صور الموردين والعملاء' then 'supplier' end) filter (where p in ('إدارة الشعار والصور','إدارة صور الأصناف والفئات','إدارة صور الموردين والعملاء')), '{}'::text[]) into v_asset_types from unnest(v_pages) p;
  if 'إدارة الشعار والصور'=any(v_pages) then v_asset_types := v_asset_types || array['splash','app_icon']::text[]; end if;
  if 'إدارة صور الأصناف والفئات'=any(v_pages) then v_asset_types := v_asset_types || array['category']::text[]; end if;
  if 'إدارة صور الموردين والعملاء'=any(v_pages) then v_asset_types := v_asset_types || array['customer','shipping_company']::text[]; end if;
  select coalesce(array_agg(distinct case p when 'سندات القبض' then 'receipt' when 'سندات الصرف' then 'payment' end) filter (where p in ('سندات القبض','سندات الصرف')), '{}'::text[]) into v_voucher_types from unnest(v_pages) p;

  -- Only allowlisted, company-scoped ERP tables are eligible. Global lookup tables,
  -- authentication identities, and the company root record are deliberately protected.
  select array_agg(distinct m.table_name order by m.table_name) into v_tables
  from unnest(v_pages) p(page_name)
  join (values
    ('بيانات الشركة','erp_company_settings'),('بيانات الشركة','erp_program_settings'),
    ('الفروع ومراكز التكلفة','erp_branches'),('الفروع ومراكز التكلفة','erp_cost_centers'),
    ('دليل الفروع','erp_branches'),('الفروع','erp_branches'),
    ('أنواع الأنشطة','erp_workspace_records'),
    ('أنواع المستخدمين','erp_user_types'),('تصنيفات المستخدمين','erp_user_classifications'),
    ('المستخدمين','erp_users'),('المستخدمين','erp_user_permission_matrix'),
    ('قوالب صلاحيات المستخدمين','erp_permission_templates'),('قوالب صلاحيات المستخدمين','erp_permission_template_rules'),
    ('صلاحيات المستخدمين','erp_user_permissions'),('صلاحيات المستخدمين','erp_user_permission_matrix'),
    ('إعدادات البرنامج','erp_program_settings'),('إعدادات البرنامج','erp_company_settings'),
    ('سجل العمليات','erp_app_activity_log'),('إدارة الشعار والصور','erp_app_assets'),('إدارة صور الأصناف والفئات','erp_app_assets'),('إدارة صور الموردين والعملاء','erp_app_assets'),('إدارة صلاحيات التطبيقات','erp_app_role_permissions'),('إدارة ألوان التطبيقات','erp_app_theme_settings'),
    ('سياسات التسعير والخصومات','erp_price_lists'),('سياسات التسعير والخصومات','erp_price_list_lines'),('سياسات التسعير والخصومات','erp_party_price_lists'),
    ('شجرة الحسابات','erp_accounts'),('الفترات المالية','erp_fiscal_periods'),
    ('مراكز التكلفة','erp_cost_centers'),('العملات','erp_currencies'),
    ('الخزائن الرئيسية والفرعية','erp_cashboxes'),('سندات القبض','erp_cash_vouchers'),('سندات الصرف','erp_cash_vouchers'),
    ('دليل المخازن','erp_warehouses'),('فئات الأصناف','erp_item_groups'),
    ('دليل الأصناف','erp_items'),('دليل الأصناف','erp_item_units'),
    ('دليل الموردين','erp_parties'),('دليل الموردين','erp_party_contacts'),('دليل الموردين','erp_party_warehouses'),
    ('دليل العملاء','erp_parties'),('دليل العملاء','erp_party_contacts'),('دليل العملاء','erp_party_warehouses'),
    ('قوائم أسعار البيع','erp_price_lists'),('قوائم أسعار البيع','erp_price_list_lines'),('قوائم أسعار البيع','erp_party_price_lists'),
    ('قوائم أسعار الموردين','erp_price_lists'),('قوائم أسعار الموردين','erp_price_list_lines'),('قوائم أسعار الموردين','erp_party_price_lists'),
    ('عروض الأصناف','erp_sales_campaigns'),('عروض الأصناف','erp_sales_campaign_items'),('الحملات التسويقية','erp_sales_campaign_items'),('قواعد العروض','erp_sales_campaign_items'),
    ('قاعدة العملاء المحتملين','erp_public_lead_staging'),
    ('الهيكل الوظيفي','erp_workspace_records'),('الإدارات والأقسام','erp_workspace_records'),('الوظائف والدرجات','erp_workspace_records'),
    ('ملف الموظف','erp_employees'),
    ('الحضور والانصراف','erp_attendance_records'),('الحضور والانصراف','erp_hr_attendance_events'),
    ('أجهزة البصمة','erp_hr_fingerprint_devices'),('الورديات','erp_hr_shifts'),('توزيع الورديات','erp_hr_shift_assignments'),
    ('الإجازات والأذونات','erp_leave_requests'),
    ('مسير الرواتب','erp_payroll_runs'),('مسير الرواتب','erp_payroll_lines'),
    ('صرف الرواتب','erp_payroll_runs'),('صرف الرواتب','erp_payroll_lines'),
    ('أهداف العملاء الشهرية','erp_customer_monthly_goals'),
    
    ('خطط العمولة','erp_commission_plans'),('خطط العمولة','erp_commission_tiers'),
    ('مسودات العمولات','erp_commission_runs'),('تقرير العمولات المستحقة','erp_commission_runs'),
    ('توزيع الأصناف على المندوبين','erp_delegate_item_assignments'),('توزيع الأصناف على المندوبين','erp_sales_representatives'),
    ('عرض سعر','erp_sales_documents'),('أمر بيع','erp_sales_documents'),('فاتورة بيع','erp_sales_documents'),
    ('فاتورة مبيعات','erp_sales_documents'),('مرتجع مبيعات','erp_sales_documents'),('فاتورة بيع','erp_sales_lines'),('أمر بيع','erp_sales_lines'),('عرض سعر','erp_sales_lines'),('مرتجع مبيعات','erp_sales_lines'),
    ('إذن تجهيز','erp_sales_fulfillment_documents'),('إذن تسليم','erp_sales_fulfillment_documents'),('إذن تجهيز','erp_stock_reservations'),('إذن تسليم','erp_stock_reservations'),
    ('إذن تحميل','erp_sales_fulfillment_documents'),('تسليم طلب','erp_sales_fulfillment_documents'),
    ('عروض أسعار','erp_sales_documents'),('أوامر البيع','erp_sales_documents'),
    ('إذن إضافة','erp_inventory_movements'),
    ('إذن صرف','erp_inventory_movements'),('تحويل مخزني','erp_inventory_movements'),('إذن إضافة','erp_stock_reservations'),('إذن صرف','erp_stock_reservations'),('تحويل مخزني','erp_stock_reservations'),('تسوية جرد','erp_inventory_movements'),('جرد فعلي','erp_inventory_movements'),
    ('أمر شراء','erp_purchase_documents'),('استلام مشتريات','erp_purchase_documents'),('فاتورة مشتريات','erp_purchase_documents'),('أمر شراء','erp_purchase_lines'),('استلام مشتريات','erp_purchase_lines'),('فاتورة مشتريات','erp_purchase_lines'),
    ('مرتجع مشتريات','erp_purchase_documents'),
    ('خريطة الحسابات التشغيلية','erp_operational_account_mappings'),
    ('قيود اليومية','erp_journal_entries'),('قائمة اعتماد القيود','erp_journal_entries'),('قيود اليومية','erp_journal_lines'),('قائمة اعتماد القيود','erp_journal_lines'),
    ('إقفال الفترة','erp_journal_entries'),
    ('إعدادات الفاتورة الإلكترونية','erp_einvoice_settings'),('سجلات الفاتورة الإلكترونية','erp_einvoice_operations'),('إعدادات البرنامج','erp_managed_apps'),
    ('واجهة API والربط الخارجي','erp_workspace_records'),('إدارة مفاتيح API','erp_workspace_records'),
    ('سجلات التكامل والطلبات','erp_workspace_records'),('إعداد نقاط الربط','erp_workspace_records'),
    ('الحملات التسويقية','erp_sales_campaigns'),('قواعد العروض','erp_sales_campaigns'),('قنوات التواصل','erp_workspace_records')
  ) as m(page_name, table_name) on m.page_name = p.page_name;

  -- Configurable workspace rows are selected by their exact screen label.
  v_tables := array_append(coalesce(v_tables, '{}'::text[]), 'erp_workspace_records');
  select array_agg(distinct x order by x) into v_tables from unnest(v_tables) x;

  foreach v_table in array v_tables loop
    if v_table = 'erp_workspace_records' then
      select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb)
        into v_rows
        from public.erp_workspace_records t
        where t.company_id = p_company_id and t.page_key = any(v_pages);
    elsif v_table = 'erp_cash_vouchers' and cardinality(v_voucher_types)>0 then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_cash_vouchers t where t.company_id=p_company_id and t.voucher_type=any(v_voucher_types);
    elsif v_table = 'erp_inventory_movements' and cardinality(v_movement_types)>0 then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_inventory_movements t where t.company_id=p_company_id and t.movement_type=any(v_movement_types);
    elsif v_table = 'erp_app_assets' and cardinality(v_asset_types)>0 then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_app_assets t join public.erp_managed_apps a on a.id=t.app_id where a.company_id=p_company_id and t.asset_type=any(v_asset_types);
    elsif v_table = 'erp_parties' then
      if cardinality(v_party_kinds) > 0 then
        select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_parties t where t.company_id=p_company_id and t.party_kind=any(v_party_kinds);
      else
        select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_parties t where t.company_id=p_company_id;
      end if;
    elsif v_table = 'erp_price_lists' then
      if cardinality(v_price_kinds) > 0 then
        select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_price_lists t where t.company_id=p_company_id and t.price_kind=any(v_price_kinds);
      else
        select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_price_lists t where t.company_id=p_company_id;
      end if;
    elsif v_table = 'erp_price_list_lines' and cardinality(v_price_kinds) > 0 then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_price_list_lines t join public.erp_price_lists l on l.id=t.price_list_id where t.company_id=p_company_id and l.company_id=p_company_id and l.price_kind=any(v_price_kinds);
    elsif v_table in ('erp_party_contacts','erp_party_warehouses') and cardinality(v_party_kinds) > 0 then
      execute format('select coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb) from public.%I t join public.erp_parties p on p.id=t.party_id where t.company_id=$1 and p.company_id=$1 and p.party_kind=any($2)', v_table) into v_rows using p_company_id, v_party_kinds;
    elsif v_table = 'erp_party_price_lists' and (cardinality(v_party_kinds) > 0 or cardinality(v_price_kinds) > 0) then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_party_price_lists t where t.company_id=p_company_id and ((cardinality(v_price_kinds)>0 and t.price_list_id in (select l.id from public.erp_price_lists l where l.company_id=p_company_id and l.price_kind=any(v_price_kinds))) or (cardinality(v_party_kinds)>0 and t.party_id in (select p.id from public.erp_parties p where p.company_id=p_company_id and p.party_kind=any(v_party_kinds))));
    elsif v_table = 'erp_sales_documents' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_sales_documents t where t.company_id=p_company_id and t.document_type=any(v_sales_types);
    elsif v_table = 'erp_purchase_documents' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_purchase_documents t where t.company_id=p_company_id and t.document_type=any(v_purchase_types);
    elsif v_table = 'erp_sales_lines' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_sales_lines t join public.erp_sales_documents d on d.id=t.document_id where d.company_id=p_company_id and d.document_type=any(v_sales_types);
    elsif v_table = 'erp_purchase_lines' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_purchase_lines t join public.erp_purchase_documents d on d.id=t.document_id where d.company_id=p_company_id and d.document_type=any(v_purchase_types);
    elsif v_table = 'erp_sales_fulfillment_documents' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows from public.erp_sales_fulfillment_documents t where t.company_id=p_company_id and (('إذن تجهيز'=any(v_pages) and t.kind='preparation') or (('إذن تسليم'=any(v_pages) or 'إذن تحميل'=any(v_pages)) and t.kind='delivery') or (cardinality(v_sales_types)>0 and t.invoice_id in (select d.id from public.erp_sales_documents d where d.company_id=p_company_id and d.document_type=any(v_sales_types))));
    elsif exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = v_table and column_name = 'company_id'
    ) then
      execute format('select coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb) from public.%I t where t.company_id = $1', v_table)
        into v_rows using p_company_id;
    elsif v_table = 'erp_journal_lines' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows
      from public.erp_journal_lines t join public.erp_journal_entries p on p.id=t.entry_id where p.company_id=p_company_id;
    elsif v_table = 'erp_sales_lines' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows
      from public.erp_sales_lines t join public.erp_sales_documents p on p.id=t.document_id where p.company_id=p_company_id;
    elsif v_table = 'erp_purchase_lines' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows
      from public.erp_purchase_lines t join public.erp_purchase_documents p on p.id=t.document_id where p.company_id=p_company_id;
    elsif v_table = 'erp_commission_tiers' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_rows
      from public.erp_commission_tiers t join public.erp_commission_plans p on p.id=t.plan_id where p.company_id=p_company_id;
    elsif v_table in ('erp_app_assets','erp_app_role_permissions','erp_app_theme_settings') then
      execute format('select coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb) from public.%I t join public.erp_managed_apps a on a.id=t.app_id where a.company_id=$1', v_table)
        into v_rows using p_company_id;
    else
      v_rows := '[]'::jsonb;
    end if;
    v_payload := jsonb_set(v_payload, array['tables', v_table], coalesce(v_rows, '[]'::jsonb), true);
    v_total := v_total + jsonb_array_length(coalesce(v_rows, '[]'::jsonb));
  end loop;

  v_backup_id := 'clear_' || replace(gen_random_uuid()::text, '-', '');
  v_payload := v_payload || jsonb_build_object('backup_id', v_backup_id, 'record_count', v_total);
  insert into public.erp_data_backups(company_id, backup_id, backup_type, selected_pages, record_count, payload, created_by)
  values (p_company_id, v_backup_id, 'selective_clear', v_pages, v_total, v_payload, v_user);

  return v_payload;
end;
$$;

create or replace function public.erp_complete_selective_data_clear(p_company_id uuid, p_backup_id text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_backup public.erp_data_backups%rowtype;
  v_pages text[];
  v_tables text[];
  v_table text;
  v_count integer := 0;
  v_deleted integer := 0;
  v_result jsonb := '{}'::jsonb;
  v_sales_types text[];
  v_purchase_types text[];
  v_price_kinds text[];
  v_party_kinds text[];
  v_movement_types text[];
  v_asset_types text[];
  v_voucher_types text[];
  v_batch integer := 0;
  v_remaining boolean := false;
begin
  if v_user is null then raise exception 'يجب تسجيل الدخول أولاً.'; end if;
  if not public.erp_user_has_company_role(p_company_id, array['owner','admin']::text[]) then
    raise exception 'هذه العملية متاحة لمالك الشركة أو مديرها فقط.';
  end if;
  select * into v_backup from public.erp_data_backups
  where company_id=p_company_id and backup_id=p_backup_id and backup_type='selective_clear';
  if not found then raise exception 'لم يتم العثور على نسخة احتياطية صالحة على السيرفر.'; end if;
  v_pages := v_backup.selected_pages;
  select coalesce(array_agg(distinct case p when 'عرض سعر' then 'quotation' when 'أمر بيع' then 'order' when 'فاتورة بيع' then 'invoice' when 'فاتورة مبيعات' then 'invoice' when 'مرتجع مبيعات' then 'return' end) filter (where p in ('عرض سعر','أمر بيع','فاتورة بيع','فاتورة مبيعات','مرتجع مبيعات')), '{}'::text[]) into v_sales_types from unnest(v_pages) p;
  select coalesce(array_agg(distinct case p when 'أمر شراء' then 'order' when 'استلام مشتريات' then 'receipt' when 'فاتورة مشتريات' then 'invoice' when 'مرتجع مشتريات' then 'return' end) filter (where p in ('أمر شراء','استلام مشتريات','فاتورة مشتريات','مرتجع مشتريات')), '{}'::text[]) into v_purchase_types from unnest(v_pages) p;
  select coalesce(array_agg(distinct case p when 'قوائم أسعار البيع' then 'sale' when 'قوائم أسعار الموردين' then 'purchase' when 'سياسات التسعير والخصومات' then 'sale' end) filter (where p in ('قوائم أسعار البيع','قوائم أسعار الموردين','سياسات التسعير والخصومات')), '{}'::text[]) into v_price_kinds from unnest(v_pages) p;
  if 'سياسات التسعير والخصومات' = any(v_pages) then v_price_kinds := array['sale','purchase']::text[]; end if;
  if 'دليل العملاء'=any(v_pages) and 'دليل الموردين'=any(v_pages) then v_party_kinds := array['customer','supplier','both']::text[];
  elsif 'دليل العملاء'=any(v_pages) then v_party_kinds := array['customer']::text[];
  elsif 'دليل الموردين'=any(v_pages) then v_party_kinds := array['supplier']::text[];
  else v_party_kinds := '{}'::text[]; end if;
  select coalesce(array_agg(distinct case p when 'إذن إضافة' then 'purchase_receipt' when 'إذن صرف' then 'sales_issue' when 'تحويل مخزني' then 'transfer_in' when 'تسوية جرد' then 'adjustment' when 'جرد فعلي' then 'adjustment' end) filter (where p in ('إذن إضافة','إذن صرف','تحويل مخزني','تسوية جرد','جرد فعلي')), '{}'::text[]) into v_movement_types from unnest(v_pages) p;
  if 'تحويل مخزني'=any(v_pages) then v_movement_types := array_append(v_movement_types,'transfer_out'); end if;
  if 'إذن صرف'=any(v_pages) then v_movement_types := v_movement_types || array['waste']::text[]; end if;
  select coalesce(array_agg(distinct case p when 'إدارة الشعار والصور' then 'app_logo' when 'إدارة صور الأصناف والفئات' then 'item' when 'إدارة صور الموردين والعملاء' then 'supplier' end) filter (where p in ('إدارة الشعار والصور','إدارة صور الأصناف والفئات','إدارة صور الموردين والعملاء')), '{}'::text[]) into v_asset_types from unnest(v_pages) p;
  if 'إدارة الشعار والصور'=any(v_pages) then v_asset_types := v_asset_types || array['splash','app_icon']::text[]; end if;
  if 'إدارة صور الأصناف والفئات'=any(v_pages) then v_asset_types := v_asset_types || array['category']::text[]; end if;
  if 'إدارة صور الموردين والعملاء'=any(v_pages) then v_asset_types := v_asset_types || array['customer','shipping_company']::text[]; end if;
  select coalesce(array_agg(distinct case p when 'سندات القبض' then 'receipt' when 'سندات الصرف' then 'payment' end) filter (where p in ('سندات القبض','سندات الصرف')), '{}'::text[]) into v_voucher_types from unnest(v_pages) p;

  -- Delete dependent rows first. Any unselected dependent rows cause a safe transaction
  -- rollback; the server backup remains available for recovery.
  v_tables := array[
    'erp_workspace_records','erp_stock_reservations','erp_sales_fulfillment_documents','erp_sales_lines','erp_customer_shortages',
    'erp_purchase_lines','erp_journal_lines','erp_commission_tiers','erp_sales_documents','erp_purchase_documents',
    'erp_sales_campaign_items','erp_party_price_lists','erp_price_list_lines',
    'erp_party_contacts','erp_party_warehouses','erp_inventory_movements','erp_cash_vouchers',
    'erp_payroll_lines','erp_payroll_runs','erp_attendance_records','erp_leave_requests',
    'erp_hr_attendance_events','erp_hr_shift_assignments','erp_commission_runs','erp_delegate_item_assignments',
    'erp_user_branch_warehouse_access','erp_user_permission_matrix','erp_permission_template_rules',
    'erp_user_permissions','erp_app_activity_log','erp_app_assets','erp_app_role_permissions','erp_app_theme_settings',
    'erp_sales_campaigns','erp_customer_monthly_goals','erp_commission_plans','erp_operational_account_mappings',
    'erp_einvoice_operations','erp_einvoice_settings','erp_public_lead_staging','erp_hr_fingerprint_devices',
    'erp_hr_shifts','erp_employees','erp_journal_entries','erp_users','erp_user_classifications',
    'erp_user_types','erp_permission_templates','erp_parties','erp_sales_representatives','erp_item_units','erp_items','erp_item_groups',
    'erp_price_lists','erp_warehouses','erp_cashboxes','erp_accounts','erp_fiscal_periods','erp_currencies',
    'erp_cost_centers','erp_branches','erp_company_settings','erp_program_settings'
  ];

  foreach v_table in array v_tables loop
    if v_table <> 'erp_workspace_records' and not (v_backup.payload->'tables' ? v_table) then continue; end if;
    if v_table = 'erp_workspace_records' then
      delete from public.erp_workspace_records where company_id=p_company_id and page_key=any(v_pages);
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_cash_vouchers' and cardinality(v_voucher_types)>0 then
      delete from public.erp_cash_vouchers where company_id=p_company_id and voucher_type=any(v_voucher_types);
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_inventory_movements' and cardinality(v_movement_types)>0 then
      delete from public.erp_inventory_movements where company_id=p_company_id and movement_type=any(v_movement_types);
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_app_assets' and cardinality(v_asset_types)>0 then
      delete from public.erp_app_assets t using public.erp_managed_apps a where a.id=t.app_id and a.company_id=p_company_id and t.asset_type=any(v_asset_types);
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_parties' then
      if cardinality(v_party_kinds)>0 then delete from public.erp_parties where company_id=p_company_id and party_kind=any(v_party_kinds);
      else delete from public.erp_parties where company_id=p_company_id; end if;
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_price_lists' then
      if cardinality(v_price_kinds)>0 then delete from public.erp_price_lists where company_id=p_company_id and price_kind=any(v_price_kinds);
      else delete from public.erp_price_lists where company_id=p_company_id; end if;
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_price_list_lines' and cardinality(v_price_kinds)>0 then
      delete from public.erp_price_list_lines t using public.erp_price_lists l where t.price_list_id=l.id and t.company_id=p_company_id and l.company_id=p_company_id and l.price_kind=any(v_price_kinds);
      get diagnostics v_deleted = row_count;
    elsif v_table in ('erp_party_contacts','erp_party_warehouses') and cardinality(v_party_kinds)>0 then
      execute format('delete from public.%I t using public.erp_parties p where p.id=t.party_id and t.company_id=$1 and p.company_id=$1 and p.party_kind=any($2)', v_table) using p_company_id, v_party_kinds;
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_party_price_lists' and (cardinality(v_party_kinds)>0 or cardinality(v_price_kinds)>0) then
      delete from public.erp_party_price_lists t where t.company_id=p_company_id and ((cardinality(v_price_kinds)>0 and t.price_list_id in (select l.id from public.erp_price_lists l where l.company_id=p_company_id and l.price_kind=any(v_price_kinds))) or (cardinality(v_party_kinds)>0 and t.party_id in (select p.id from public.erp_parties p where p.company_id=p_company_id and p.party_kind=any(v_party_kinds))));
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_sales_documents' then
      delete from public.erp_sales_documents where company_id=p_company_id and document_type=any(v_sales_types);
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_purchase_documents' then
      delete from public.erp_purchase_documents where company_id=p_company_id and document_type=any(v_purchase_types);
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_sales_lines' then
      delete from public.erp_sales_lines t using public.erp_sales_documents d where d.id=t.document_id and d.company_id=p_company_id and d.document_type=any(v_sales_types);
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_purchase_lines' then
      delete from public.erp_purchase_lines t using public.erp_purchase_documents d where d.id=t.document_id and d.company_id=p_company_id and d.document_type=any(v_purchase_types);
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_customer_shortages' and cardinality(v_sales_types)>0 then
      delete from public.erp_customer_shortages t where t.company_id=p_company_id and (t.source_document_id in (select d.id from public.erp_sales_documents d where d.company_id=p_company_id and d.document_type=any(v_sales_types)) );
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_stock_reservations' and cardinality(v_sales_types)>0  then
      delete from public.erp_stock_reservations t where t.company_id=p_company_id and (t.sales_document_id in (select d.id from public.erp_sales_documents d where d.company_id=p_company_id and d.document_type=any(v_sales_types)) or t.sales_line_id in (select l.id from public.erp_sales_lines l join public.erp_sales_documents d on d.id=l.document_id where d.company_id=p_company_id and d.document_type=any(v_sales_types)));
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_sales_fulfillment_documents' then
      delete from public.erp_sales_fulfillment_documents t where t.company_id=p_company_id and (('إذن تجهيز'=any(v_pages) and t.kind='preparation') or (('إذن تسليم'=any(v_pages) or 'إذن تحميل'=any(v_pages)) and t.kind='delivery') or (cardinality(v_sales_types)>0 and t.invoice_id in (select d.id from public.erp_sales_documents d where d.company_id=p_company_id and d.document_type=any(v_sales_types))));
      get diagnostics v_deleted = row_count;
    elsif v_table in ('erp_accounts','erp_item_groups','erp_cost_centers') then
      v_deleted := 0;
      loop
        execute format('delete from public.%I x where x.company_id=$1 and not exists (select 1 from public.%I c where c.company_id=$1 and c.parent_id=x.id)', v_table, v_table) using p_company_id;
        get diagnostics v_batch = row_count;
        v_deleted := v_deleted + v_batch;
        exit when v_batch = 0;
      end loop;
      if exists (select 1 from information_schema.columns where table_schema='public' and table_name=v_table and column_name='parent_id') then
        execute format('select exists(select 1 from public.%I where company_id=$1)', v_table) into v_remaining using p_company_id;
        if v_remaining then raise exception 'تعذر مسح شجرة % بسبب علاقة دائرية أو سجل تابع غير قابل للحذف؛ النسخة الاحتياطية محفوظة.', v_table; end if;
      end if;
    elsif exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name=v_table and column_name='company_id'
    ) then
      execute format('delete from public.%I where company_id=$1', v_table) using p_company_id;
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_journal_lines' then
      delete from public.erp_journal_lines t using public.erp_journal_entries p
      where t.entry_id=p.id and p.company_id=p_company_id;
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_sales_lines' then
      delete from public.erp_sales_lines t using public.erp_sales_documents p
      where t.document_id=p.id and p.company_id=p_company_id;
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_purchase_lines' then
      delete from public.erp_purchase_lines t using public.erp_purchase_documents p
      where t.document_id=p.id and p.company_id=p_company_id;
      get diagnostics v_deleted = row_count;
    elsif v_table = 'erp_commission_tiers' then
      delete from public.erp_commission_tiers t using public.erp_commission_plans p
      where t.plan_id=p.id and p.company_id=p_company_id;
      get diagnostics v_deleted = row_count;
    elsif v_table in ('erp_app_assets','erp_app_role_permissions','erp_app_theme_settings') then
      execute format('delete from public.%I t using public.erp_managed_apps a where a.id=t.app_id and a.company_id=$1', v_table)
        using p_company_id;
      get diagnostics v_deleted = row_count;
    else
      v_deleted := 0;
    end if;
    v_result := jsonb_set(v_result, array[v_table], to_jsonb(v_deleted), true);
    v_count := v_count + v_deleted;
  end loop;

  return jsonb_build_object('success', true, 'deleted_count', v_count, 'deleted_by_table', v_result, 'backup_id', p_backup_id);
end;
$$;

revoke all on function public.erp_prepare_selective_data_clear(uuid, text[]) from public, anon;
revoke all on function public.erp_complete_selective_data_clear(uuid, text) from public, anon;
grant execute on function public.erp_prepare_selective_data_clear(uuid, text[]) to authenticated;
grant execute on function public.erp_complete_selective_data_clear(uuid, text) to authenticated;

commit;
