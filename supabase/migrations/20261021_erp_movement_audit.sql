-- Data-driven ERP audit for currently implemented ERP tables.
-- Read-only: reports findings and never changes source records.
create or replace function public.erp_run_movement_audit(
  p_company_id uuid,
  p_start_date date default null,
  p_end_date date default null,
  p_area text default 'كل الحركات'
)
returns table (
  issue_id text,
  area text,
  document_id uuid,
  document_number text,
  document_date date,
  document_title text,
  severity text,
  issue_code text,
  issue_message text,
  repair_route text
)
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_company_id is null then
    raise exception 'معرّف الشركة مطلوب';
  end if;
  if p_start_date is not null and p_end_date is not null and p_start_date > p_end_date then
    raise exception 'تاريخ البداية يجب ألا يتجاوز تاريخ النهاية';
  end if;

  return query
  select
    'journal:' || e.id::text || ':lines' as issue_id,
    'القيود المحاسبية'::text as area,
    e.id as document_id,
    e.entry_number::text as document_number,
    e.entry_date as document_date,
    e.description as document_title,
    'خطأ'::text as severity,
    'JOURNAL_NO_LINES'::text as issue_code,
    'القيد لا يحتوي على أي سطور.'::text as issue_message,
    case when e.status = 'draft' then 'journal_draft' else 'journal_reversal' end::text as repair_route
  from public.erp_journal_entries e
  where e.company_id = p_company_id
    and (p_start_date is null or e.entry_date >= p_start_date)
    and (p_end_date is null or e.entry_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'القيود المحاسبية')
    and not exists (select 1 from public.erp_journal_lines l where l.entry_id = e.id)

  union all

  select
    'journal:' || e.id::text || ':balance',
    'القيود المحاسبية',
    e.id,
    e.entry_number::text,
    e.entry_date,
    e.description,
    'خطأ',
    'JOURNAL_UNBALANCED',
    'إجمالي المدين لا يساوي إجمالي الدائن أو يساوي صفرًا.',
    case when e.status = 'draft' then 'journal_draft' else 'journal_reversal' end
  from public.erp_journal_entries e
  join lateral (
    select count(*) as line_count, coalesce(sum(l.debit),0) as debit_total,
      coalesce(sum(l.credit),0) as credit_total
    from public.erp_journal_lines l where l.entry_id = e.id
  ) s on true
  where e.company_id = p_company_id
    and (p_start_date is null or e.entry_date >= p_start_date)
    and (p_end_date is null or e.entry_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'القيود المحاسبية')
    and s.line_count > 0
    and (s.line_count < 2 or s.debit_total <= 0 or s.debit_total <> s.credit_total)

  union all

  select
    'journal:' || e.id::text || ':account',
    'القيود المحاسبية',
    e.id,
    e.entry_number::text,
    e.entry_date,
    e.description,
    'خطأ',
    'JOURNAL_INVALID_ACCOUNT',
    'يوجد حساب غير نشط أو غير قابل للترحيل أو لا يتبع الشركة نفسها.',
    case when e.status = 'draft' then 'journal_draft' else 'journal_reversal' end
  from public.erp_journal_entries e
  where e.company_id = p_company_id
    and (p_start_date is null or e.entry_date >= p_start_date)
    and (p_end_date is null or e.entry_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'القيود المحاسبية')
    and exists (
      select 1
      from public.erp_journal_lines l
      left join public.erp_accounts a on a.id = l.account_id
      where l.entry_id = e.id
        and (a.id is null or a.company_id <> e.company_id or not a.is_active or not a.is_postable)
    )

  union all

  select
    'journal:' || e.id::text || ':period',
    'القيود المحاسبية',
    e.id,
    e.entry_number::text,
    e.entry_date,
    e.description,
    'خطأ',
    'JOURNAL_CLOSED_PERIOD',
    'تاريخ القيد يقع داخل فترة مالية مغلقة.',
    case when e.status = 'draft' then 'journal_draft' else 'journal_reversal' end
  from public.erp_journal_entries e
  where e.company_id = p_company_id
    and (p_start_date is null or e.entry_date >= p_start_date)
    and (p_end_date is null or e.entry_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'القيود المحاسبية')
    and exists (
      select 1 from public.erp_fiscal_periods fp
      where fp.company_id = e.company_id
        and e.entry_date between fp.starts_on and fp.ends_on
        and fp.status = 'closed'
    )

  union all

  select
    'account:' || a.id::text || ':parent',
    'الحسابات',
    a.id,
    a.account_code,
    null::date,
    a.account_name,
    'خطأ',
    'ACCOUNT_INVALID_PARENT',
    'الحساب الأب لا يتبع الشركة نفسها أو أنه حساب تحليلي قابل للترحيل.',
    'accounts'
  from public.erp_accounts a
  left join public.erp_accounts p on p.id = a.parent_id
  where a.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الحسابات')
    and a.parent_id is not null
    and (p.id is null or p.company_id <> a.company_id or p.is_postable)

  union all

  select
    'account:' || a.id::text || ':children',
    'الحسابات',
    a.id,
    a.account_code,
    null::date,
    a.account_name,
    'خطأ',
    'ACCOUNT_POSTABLE_WITH_CHILDREN',
    'الحساب قابل للترحيل رغم وجود حسابات فرعية تحته.',
    'accounts'
  from public.erp_accounts a
  where a.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الحسابات')
    and a.is_postable
    and exists (
      select 1 from public.erp_accounts child
      where child.parent_id = a.id and child.company_id = a.company_id
    )

  union all

  (with recursive account_walk(start_id, current_id, company_id, path, has_cycle) as (
    select a.id, a.id, a.company_id, array[a.id]::uuid[], false
    from public.erp_accounts a
    where a.company_id = p_company_id
    union all
    select w.start_id, child.id, w.company_id, w.path || child.id,
      child.id = any(w.path)
    from account_walk w
    join public.erp_accounts child
      on child.parent_id = w.current_id
     and child.company_id = w.company_id
    where not w.has_cycle
  )
  select
    'account:' || a.id::text || ':cycle',
    'الحسابات',
    a.id,
    a.account_code,
    null::date,
    a.account_name,
    'خطأ',
    'ACCOUNT_HIERARCHY_CYCLE',
    'يوجد مسار دائري في شجرة الحسابات؛ يجب تصحيح العلاقة يدويًا قبل استخدام التقارير الهرمية.',
    'accounts'
  from public.erp_accounts a
  where a.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الحسابات')
    and a.id in (select start_id from account_walk where has_cycle))

  union all

  select
    'cashbox:' || c.id::text || ':account',
    'الخزائن والبنوك',
    c.id,
    c.cashbox_code,
    null::date,
    c.cashbox_name,
    'تحذير',
    'CASHBOX_ACCOUNT_MISSING',
    'الخزينة أو الحساب البنكي غير مربوط بحساب أستاذ عام صالح.',
    'cashboxes'
  from public.erp_cashboxes c
  left join public.erp_accounts a on a.id = c.account_id
  where c.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الخزائن' or p_area = 'البنوك')
    and (c.account_id is null or a.id is null or a.company_id <> c.company_id or not a.is_active or not a.is_postable)


  union all

  select
    'warehouse:' || w.id::text || ':branch',
    'المخازن',
    w.id,
    w.warehouse_code,
    null::date,
    w.warehouse_name,
    'خطأ',
    'WAREHOUSE_BRANCH_COMPANY_MISMATCH',
    'المخزن مربوط بفرع تابع لشركة أخرى أو بفرع غير موجود.',
    'warehouses'
  from public.erp_warehouses w
  left join public.erp_branches b on b.id = w.branch_id
  where w.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'المخازن')
    and w.branch_id is not null
    and (b.id is null or b.company_id <> w.company_id)

  union all

  select
    'cashbox:' || c.id::text || ':branch',
    'الخزائن والبنوك',
    c.id,
    c.cashbox_code,
    null::date,
    c.cashbox_name,
    'خطأ',
    'CASHBOX_BRANCH_COMPANY_MISMATCH',
    'الخزينة أو الحساب البنكي مربوط بفرع لا يتبع الشركة نفسها.',
    'cashboxes'
  from public.erp_cashboxes c
  left join public.erp_branches b on b.id = c.branch_id
  where c.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الخزائن' or p_area = 'البنوك')
    and c.branch_id is not null
    and (b.id is null or b.company_id <> c.company_id)

  union all

  select
    'item:' || i.id::text || ':group',
    'الأصناف',
    i.id,
    i.item_code,
    null::date,
    i.item_name,
    'خطأ',
    'ITEM_GROUP_COMPANY_MISMATCH',
    'فئة الصنف لا تتبع الشركة نفسها أو أنها غير موجودة.',
    'groups'
  from public.erp_items i
  left join public.erp_item_groups g on g.id = i.group_id
  where i.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الأصناف')
    and i.group_id is not null
    and (g.id is null or g.company_id <> i.company_id)

  union all

  select
    'fiscal-period:' || p1.id::text || ':overlap',
    'الفترات المالية',
    p1.id,
    p1.period_name,
    p1.starts_on,
    p1.period_name,
    'تحذير',
    'FISCAL_PERIOD_OVERLAP',
    'توجد فترة مالية أخرى متداخلة مع هذه الفترة داخل الشركة.',
    'fiscal_periods'
  from public.erp_fiscal_periods p1
  where p1.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الفترات المالية')
    and exists (
      select 1
      from public.erp_fiscal_periods p2
      where p2.company_id = p1.company_id
        and p2.id <> p1.id
        and daterange(p2.starts_on, p2.ends_on, '[]')
            && daterange(p1.starts_on, p1.ends_on, '[]')
    )

  union all

  select
    'journal:' || e.id::text || ':period_missing',
    'القيود المحاسبية',
    e.id,
    e.entry_number::text,
    e.entry_date,
    e.description,
    'تحذير',
    'JOURNAL_NO_FISCAL_PERIOD',
    'تاريخ القيد لا يقع داخل أي فترة مالية معرفة للشركة.',
    case when e.status = 'draft' then 'journal_draft' else 'journal_reversal' end
  from public.erp_journal_entries e
  where e.company_id = p_company_id
    and (p_start_date is null or e.entry_date >= p_start_date)
    and (p_end_date is null or e.entry_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'القيود المحاسبية')
    and not exists (
      select 1 from public.erp_fiscal_periods fp
      where fp.company_id = e.company_id
        and e.entry_date between fp.starts_on and fp.ends_on
    )


  union all

  select
    'stock:' || b.warehouse_id::text || ':' || b.item_id::text || ':negative',
    'المخزون',
    b.item_id,
    i.item_code,
    b.negative_date,
    i.item_name || ' — ' || w.warehouse_name,
    'خطأ',
    'STOCK_NEGATIVE_BALANCE',
    'رصيد الصنف بالمخزن أصبح سالبًا خلال الفترة المحددة؛ راجع الحركة التي سببت العجز والتسويات اللاحقة.',
    'inventory'
  from (
    select distinct on (x.company_id, x.warehouse_id, x.item_id)
      x.company_id, x.warehouse_id, x.item_id, x.movement_date::date as negative_date
    from (
      select m.company_id, m.warehouse_id, m.item_id, m.movement_date,
        sum(m.quantity_in - m.quantity_out) over (
          partition by m.company_id, m.warehouse_id, m.item_id
          order by m.movement_date, m.created_at, m.id
          rows between unbounded preceding and current row
        ) as balance_after
      from public.erp_inventory_movements m
      where m.company_id = p_company_id
        and (p_end_date is null or m.movement_date::date <= p_end_date)
        and (p_end_date is not null or m.movement_date <= now())
    ) x
    where x.balance_after < 0
      and (p_start_date is null or x.movement_date::date >= p_start_date)
      and (p_end_date is null or x.movement_date::date <= p_end_date)
    order by x.company_id, x.warehouse_id, x.item_id, x.movement_date
  ) b
  join public.erp_items i on i.id = b.item_id
  join public.erp_warehouses w on w.id = b.warehouse_id
  where (p_area = 'كل الحركات' or p_area = 'المخزون')

  union all

  select
    'stock:' || m.id::text || ':ownership',
    'المخزون',
    m.id,
    m.movement_type,
    m.movement_date::date,
    coalesce(i.item_name, 'صنف غير موجود') || ' — ' || coalesce(w.warehouse_name, 'مخزن غير موجود'),
    'خطأ',
    'STOCK_COMPANY_MISMATCH',
    'حركة المخزون تشير إلى صنف أو مخزن أو فرع لا يتبع الشركة نفسها.',
    'inventory'
  from public.erp_inventory_movements m
  left join public.erp_items i on i.id = m.item_id
  left join public.erp_warehouses w on w.id = m.warehouse_id
  left join public.erp_branches b on b.id = m.branch_id
  where m.company_id = p_company_id
    and (p_start_date is null or m.movement_date::date >= p_start_date)
    and (p_end_date is null or m.movement_date::date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المخزون')
    and (
      i.id is null or i.company_id <> m.company_id
      or w.id is null or w.company_id <> m.company_id
      or (m.branch_id is not null and (b.id is null or b.company_id <> m.company_id))
    )


  union all

  select
    'purchase:' || d.id::text || ':references',
    'المشتريات',
    d.id,
    d.document_number,
    d.document_date,
    'مستند مشتريات',
    'خطأ',
    'PURCHASE_REFERENCE_MISMATCH',
    'المورد أو المخزن في مستند المشتريات لا يتبع الشركة نفسها أو غير موجود.',
    'purchases'
  from public.erp_purchase_documents d
  left join public.erp_parties p on p.id = d.supplier_id
  left join public.erp_warehouses w on w.id = d.warehouse_id
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المشتريات' or p_area = 'الموردون')
    and (
      p.id is null or p.company_id <> d.company_id
      or p.party_kind not in ('supplier','both')
      or (d.warehouse_id is not null and (w.id is null or w.company_id <> d.company_id))
    )

  union all

  select
    'purchase:' || d.id::text || ':lines',
    'المشتريات',
    d.id,
    d.document_number,
    d.document_date,
    'مستند مشتريات',
    'تحذير',
    'PURCHASE_WITHOUT_LINES',
    'مستند المشتريات ليس له أي بنود.',
    'purchases'
  from public.erp_purchase_documents d
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المشتريات' or p_area = 'الموردون')
    and not exists (select 1 from public.erp_purchase_lines l where l.document_id = d.id)

  union all

  select
    'purchase-line:' || l.id::text || ':item',
    'المشتريات',
    d.id,
    d.document_number,
    d.document_date,
    'بند مشتريات غير صحيح',
    'خطأ',
    'PURCHASE_LINE_ITEM_MISMATCH',
    'صنف بند المشتريات لا يتبع شركة المستند.',
    'purchases'
  from public.erp_purchase_lines l
  join public.erp_purchase_documents d on d.id = l.document_id
  left join public.erp_items i on i.id = l.item_id
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المشتريات' or p_area = 'الموردون')
    and (i.id is null or i.company_id <> d.company_id)

  union all

  select
    'sale:' || d.id::text || ':references',
    'المبيعات',
    d.id,
    d.document_number,
    d.document_date,
    'مستند مبيعات',
    'خطأ',
    'SALE_REFERENCE_MISMATCH',
    'العميل أو المخزن في مستند المبيعات لا يتبع الشركة نفسها أو غير موجود.',
    'sales'
  from public.erp_sales_documents d
  left join public.erp_parties p on p.id = d.customer_id
  left join public.erp_warehouses w on w.id = d.warehouse_id
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المبيعات' or p_area = 'العملاء')
    and (
      p.id is null or p.company_id <> d.company_id
      or p.party_kind not in ('customer','both')
      or (d.warehouse_id is not null and (w.id is null or w.company_id <> d.company_id))
    )

  union all

  select
    'sale:' || d.id::text || ':lines',
    'المبيعات',
    d.id,
    d.document_number,
    d.document_date,
    'مستند مبيعات',
    'تحذير',
    'SALE_WITHOUT_LINES',
    'مستند المبيعات ليس له أي بنود.',
    'sales'
  from public.erp_sales_documents d
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المبيعات' or p_area = 'العملاء')
    and not exists (select 1 from public.erp_sales_lines l where l.document_id = d.id)

  union all

  select
    'sale-line:' || l.id::text || ':item',
    'المبيعات',
    d.id,
    d.document_number,
    d.document_date,
    'بند مبيعات غير صحيح',
    'خطأ',
    'SALE_LINE_ITEM_MISMATCH',
    'صنف بند المبيعات لا يتبع شركة المستند.',
    'sales'
  from public.erp_sales_lines l
  join public.erp_sales_documents d on d.id = l.document_id
  left join public.erp_items i on i.id = l.item_id
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المبيعات' or p_area = 'العملاء')
    and (i.id is null or i.company_id <> d.company_id)


  union all

  select
    'employee:' || e.id::text || ':branch',
    'الموظفون',
    e.id,
    e.employee_code,
    e.hire_date,
    e.full_name,
    'خطأ',
    'EMPLOYEE_BRANCH_MISMATCH',
    'فرع الموظف لا يتبع الشركة نفسها أو أن الفرع غير موجود.',
    'hr'
  from public.erp_employees e
  left join public.erp_branches b on b.id = e.branch_id
  where e.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الموظفون')
    and e.branch_id is not null
    and (b.id is null or b.company_id <> e.company_id)

  union all

  select
    'attendance:' || a.id::text || ':employee',
    'الحضور والانصراف',
    a.id,
    e.employee_code,
    a.work_date,
    e.full_name,
    'خطأ',
    'ATTENDANCE_EMPLOYEE_MISMATCH',
    'سجل الحضور يشير إلى موظف لا يتبع الشركة نفسها أو غير موجود.',
    'hr'
  from public.erp_attendance_records a
  left join public.erp_employees e on e.id = a.employee_id
  where a.company_id = p_company_id
    and (p_start_date is null or a.work_date >= p_start_date)
    and (p_end_date is null or a.work_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'الحضور والانصراف')
    and (e.id is null or e.company_id <> a.company_id)

  union all

  select
    'attendance:' || a.id::text || ':checkin',
    'الحضور والانصراف',
    a.id,
    e.employee_code,
    a.work_date,
    e.full_name,
    'تحذير',
    'ATTENDANCE_NO_CHECKIN',
    'سجل الحضور بحالة حضور أو تأخير لا يحتوي على وقت دخول.',
    'hr'
  from public.erp_attendance_records a
  join public.erp_employees e on e.id = a.employee_id
  where a.company_id = p_company_id
    and (p_start_date is null or a.work_date >= p_start_date)
    and (p_end_date is null or a.work_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'الحضور والانصراف')
    and a.attendance_status in ('present','late')
    and a.check_in is null

  union all

  select
    'leave:' || l.id::text || ':employee',
    'الإجازات',
    l.id,
    e.employee_code,
    l.starts_on,
    e.full_name,
    'خطأ',
    'LEAVE_EMPLOYEE_MISMATCH',
    'طلب الإجازة يشير إلى موظف لا يتبع الشركة نفسها أو غير موجود.',
    'hr'
  from public.erp_leave_requests l
  left join public.erp_employees e on e.id = l.employee_id
  where l.company_id = p_company_id
    and (p_start_date is null or l.starts_on >= p_start_date)
    and (p_end_date is null or l.starts_on <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'الإجازات')
    and (e.id is null or e.company_id <> l.company_id)

  union all

  select
    'payroll:' || r.id::text || ':totals',
    'الرواتب',
    r.id,
    r.run_code,
    r.period_start,
    'مسير رواتب',
    'خطأ',
    'PAYROLL_TOTAL_MISMATCH',
    'إجماليات مسير الرواتب لا تتفق مع مجموع تفاصيل الموظفين.',
    'hr'
  from public.erp_payroll_runs r
  left join lateral (
    select count(*)::integer as employee_count,
      coalesce(sum(l.gross_amount),0)::numeric(16,2) as gross_total,
      coalesce(sum(l.deductions),0)::numeric(16,2) as deduction_total,
      coalesce(sum(l.net_amount),0)::numeric(16,2) as net_total
    from public.erp_payroll_lines l where l.payroll_run_id = r.id
  ) s on true
  where r.company_id = p_company_id
    and (p_start_date is null or r.period_start >= p_start_date)
    and (p_end_date is null or r.period_start <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'الرواتب')
    and (r.employee_count <> s.employee_count or r.gross_total <> s.gross_total
      or r.deduction_total <> s.deduction_total or r.net_total <> s.net_total)

  union all

  select
    'payroll-line:' || l.id::text || ':employee',
    'الرواتب',
    r.id,
    r.run_code,
    r.period_start,
    'تفصيل راتب بموظف غير تابع للشركة',
    'خطأ',
    'PAYROLL_EMPLOYEE_MISMATCH',
    'تفصيل مسير الرواتب يشير إلى موظف لا يتبع الشركة نفسها.',
    'hr'
  from public.erp_payroll_lines l
  join public.erp_payroll_runs r on r.id = l.payroll_run_id
  left join public.erp_employees e on e.id = l.employee_id
  where r.company_id = p_company_id
    and (p_start_date is null or r.period_start >= p_start_date)
    and (p_end_date is null or r.period_start <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'الرواتب')
    and (e.id is null or e.company_id <> r.company_id)


  union all

  select
    'cash-voucher:' || v.id::text || ':journal',
    'سندات الخزائن',
    v.id,
    v.voucher_number,
    v.voucher_date,
    v.description,
    'خطأ',
    'CASH_VOUCHER_POSTED_WITHOUT_JOURNAL',
    'سند الخزينة مرحّل لكن لا يرتبط بقيد يومية مرحّل صالح.',
    'cash_vouchers'
  from public.erp_cash_vouchers v
  left join public.erp_journal_entries j on j.id = v.journal_entry_id
  where v.company_id = p_company_id
    and (p_start_date is null or v.voucher_date >= p_start_date)
    and (p_end_date is null or v.voucher_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'سندات الخزائن')
    and v.status = 'posted'
    and (j.id is null or j.company_id <> v.company_id or j.status <> 'posted')

  union all

  select
    'cash-voucher:' || v.id::text || ':account',
    'سندات الخزائن',
    v.id,
    v.voucher_number,
    v.voucher_date,
    v.description,
    'خطأ',
    'CASH_VOUCHER_INVALID_CASHBOX',
    'سند الخزينة مرتبط بخزينة غير صالحة أو بحساب أستاذ غير نشط.',
    'cash_vouchers'
  from public.erp_cash_vouchers v
  left join public.erp_cashboxes c on c.id = v.source_cashbox_id
  left join public.erp_accounts a on a.id = c.account_id
  where v.company_id = p_company_id
    and (p_start_date is null or v.voucher_date >= p_start_date)
    and (p_end_date is null or v.voucher_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'سندات الخزائن')
    and (c.id is null or c.company_id <> v.company_id or not c.is_active
      or a.id is null or a.company_id <> v.company_id or not a.is_active or not a.is_postable)


  union all

  select
    'journal:' || e.id::text || ':posting_metadata',
    'القيود المحاسبية',
    e.id,
    e.entry_number::text,
    e.entry_date,
    e.description,
    'تحذير',
    'JOURNAL_POST_METADATA_MISSING',
    'القيد مرحّل لكن بيانات المستخدم أو توقيت الترحيل ناقصة.',
    'journal_reversal'
  from public.erp_journal_entries e
  where e.company_id = p_company_id
    and (p_start_date is null or e.entry_date >= p_start_date)
    and (p_end_date is null or e.entry_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'القيود المحاسبية')
    and e.status = 'posted'
    and (e.posted_by is null or e.posted_at is null)


  union all

  select
    'purchase:' || d.id::text || ':totals',
    'المشتريات',
    d.id,
    d.document_number,
    d.document_date,
    'إجماليات مستند مشتريات غير مطابقة',
    'خطأ',
    'PURCHASE_TOTALS_MISMATCH',
    'إجماليات رأس المستند لا تطابق مجموع البنود.',
    'purchases'
  from public.erp_purchase_documents d
  left join lateral (
    select coalesce(sum(round(l.quantity * l.unit_price,2)),0) as subtotal,
      coalesce(sum(l.discount_amount),0) as discount_total,
      coalesce(sum(l.tax_amount),0) as tax_total,
      coalesce(sum(l.line_total),0) as grand_total
    from public.erp_purchase_lines l where l.document_id = d.id
  ) s on true
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المشتريات' or p_area = 'الموردون')
    and (d.subtotal <> s.subtotal or d.discount_total <> s.discount_total
      or d.tax_total <> s.tax_total or d.grand_total <> s.grand_total
      or d.grand_total <> s.subtotal - s.discount_total + s.tax_total)

  union all

  select
    'sale:' || d.id::text || ':totals',
    'المبيعات',
    d.id,
    d.document_number,
    d.document_date,
    'إجماليات مستند مبيعات غير مطابقة',
    'خطأ',
    'SALE_TOTALS_MISMATCH',
    'إجماليات رأس المستند لا تطابق مجموع البنود.',
    'sales'
  from public.erp_sales_documents d
  left join lateral (
    select coalesce(sum(round(l.quantity * l.unit_price,2)),0) as subtotal,
      coalesce(sum(l.discount_amount),0) as discount_total,
      coalesce(sum(l.tax_amount),0) as tax_total,
      coalesce(sum(l.line_total),0) as grand_total
    from public.erp_sales_lines l where l.document_id = d.id
  ) s on true
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المبيعات' or p_area = 'العملاء')
    and (d.subtotal <> s.subtotal or d.discount_total <> s.discount_total
      or d.tax_total <> s.tax_total or d.grand_total <> s.grand_total
      or d.grand_total <> s.subtotal - s.discount_total + s.tax_total)


  union all

  select
    'cash-voucher:' || v.id::text || ':destination',
    'سندات الخزائن',
    v.id,
    v.voucher_number,
    v.voucher_date,
    v.description,
    'خطأ',
    'CASH_TRANSFER_DESTINATION_INVALID',
    'سند التحويل مرتبط بخزينة استلام غير صالحة أو بحساب أستاذ غير نشط.',
    'cashboxes'
  from public.erp_cash_vouchers v
  left join public.erp_cashboxes c on c.id = v.destination_cashbox_id
  left join public.erp_accounts a on a.id = c.account_id
  where v.company_id = p_company_id
    and (p_start_date is null or v.voucher_date >= p_start_date)
    and (p_end_date is null or v.voucher_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'سندات الخزائن')
    and v.voucher_type = 'transfer'
    and (c.id is null or c.company_id <> v.company_id or not c.is_active
      or a.id is null or a.company_id <> v.company_id or not a.is_active or not a.is_postable)


  union all

  select
    'leave:' || l1.id::text || ':overlap:' || l2.id::text,
    'الإجازات',
    l1.id,
    e.employee_code,
    l1.starts_on,
    e.full_name,
    'تحذير',
    'APPROVED_LEAVE_OVERLAP',
    'يوجد طلبا إجازة معتمدان متداخلان للموظف نفسه.',
    'hr'
  from public.erp_leave_requests l1
  join public.erp_leave_requests l2
    on l2.employee_id = l1.employee_id
   and l2.company_id = l1.company_id
   and l2.id > l1.id
   and daterange(l1.starts_on, l1.ends_on, '[]') && daterange(l2.starts_on, l2.ends_on, '[]')
  join public.erp_employees e on e.id = l1.employee_id
  where l1.company_id = p_company_id
    and l1.status = 'approved' and l2.status = 'approved'
    and (p_start_date is null or l1.starts_on >= p_start_date)
    and (p_end_date is null or l1.starts_on <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'الإجازات')


  union all

  select
    'purchase:' || d.id::text || ':branch',
    'المشتريات',
    d.id,
    d.document_number,
    d.document_date,
    'فرع المستند لا يطابق فرع المخزن',
    'خطأ',
    'PURCHASE_BRANCH_WAREHOUSE_MISMATCH',
    'فرع مستند المشتريات يختلف عن فرع المخزن المرتبط به.',
    'purchases'
  from public.erp_purchase_documents d
  join public.erp_warehouses w on w.id = d.warehouse_id
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المشتريات' or p_area = 'الموردون')
    and w.branch_id is not null and d.branch_id is distinct from w.branch_id

  union all

  select
    'sale:' || d.id::text || ':branch',
    'المبيعات',
    d.id,
    d.document_number,
    d.document_date,
    'فرع المستند لا يطابق فرع المخزن',
    'خطأ',
    'SALE_BRANCH_WAREHOUSE_MISMATCH',
    'فرع مستند المبيعات يختلف عن فرع المخزن المرتبط به.',
    'sales'
  from public.erp_sales_documents d
  join public.erp_warehouses w on w.id = d.warehouse_id
  where d.company_id = p_company_id
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المبيعات' or p_area = 'العملاء')
    and w.branch_id is not null and d.branch_id is distinct from w.branch_id

  union all

  select
    'purchase:' || d.id::text || ':stock_movements',
    'المشتريات',
    d.id,
    d.document_number,
    d.document_date,
    'حركات المخزون لا تطابق بنود المستند',
    'خطأ',
    'PURCHASE_STOCK_MOVEMENT_MISMATCH',
    'المستند مرحّل لكن عدد حركات المخزون المرتبطة به لا يساوي عدد البنود.',
    'purchases'
  from public.erp_purchase_documents d
  left join lateral (
    select count(*)::bigint as line_count from public.erp_purchase_lines l where l.document_id = d.id
  ) lines on true
  left join lateral (
    select count(*)::bigint as movement_count
    from public.erp_inventory_movements m
    where m.company_id = d.company_id and m.reference_type = 'purchase_document' and m.reference_id = d.id
      and m.movement_type = case when d.document_type = 'return' then 'supplier_return' else 'purchase_receipt' end
  ) moves on true
  where d.company_id = p_company_id and d.status = 'posted'
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المشتريات' or p_area = 'الموردون')
    and lines.line_count <> moves.movement_count

  union all

  select
    'sale:' || d.id::text || ':stock_movements',
    'المبيعات',
    d.id,
    d.document_number,
    d.document_date,
    'حركات المخزون لا تطابق بنود المستند',
    'خطأ',
    'SALE_STOCK_MOVEMENT_MISMATCH',
    'المستند مرحّل لكن عدد حركات المخزون المرتبطة به لا يساوي عدد البنود.',
    'sales'
  from public.erp_sales_documents d
  left join lateral (
    select count(*)::bigint as line_count from public.erp_sales_lines l where l.document_id = d.id
  ) lines on true
  left join lateral (
    select count(*)::bigint as movement_count
    from public.erp_inventory_movements m
    where m.company_id = d.company_id and m.reference_type = 'sales_document' and m.reference_id = d.id
      and m.movement_type = case when d.document_type = 'return' then 'customer_return' else 'sales_issue' end
  ) moves on true
  where d.company_id = p_company_id and d.status = 'posted'
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and (p_area = 'كل الحركات' or p_area = 'المبيعات' or p_area = 'العملاء')
    and lines.line_count <> moves.movement_count

  union all

  select
    'item-group:' || g.id::text || ':parent',
    'فئات الأصناف',
    g.id,
    g.group_code,
    null::date,
    g.group_name,
    'خطأ',
    'ITEM_GROUP_PARENT_INVALID',
    'المجموعة الرئيسية غير موجودة أو لا تتبع الشركة نفسها.',
    'groups'
  from public.erp_item_groups g
  left join public.erp_item_groups p on p.id = g.parent_id
  where g.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الأصناف' or p_area = 'فئات الأصناف')
    and g.parent_id is not null
    and (p.id is null or p.company_id <> g.company_id)

  union all

  (with recursive group_walk(start_id, current_id, company_id, path, has_cycle) as (
    select g.id, g.id, g.company_id, array[g.id]::uuid[], false
    from public.erp_item_groups g where g.company_id = p_company_id
    union all
    select w.start_id, child.id, w.company_id, w.path || child.id, child.id = any(w.path)
    from group_walk w
    join public.erp_item_groups child on child.parent_id = w.current_id and child.company_id = w.company_id
    where not w.has_cycle
  )
  select
    'item-group:' || g.id::text || ':cycle',
    'فئات الأصناف',
    g.id,
    g.group_code,
    null::date,
    g.group_name,
    'خطأ',
    'ITEM_GROUP_HIERARCHY_CYCLE',
    'توجد علاقة دائرية في شجرة فئات الأصناف.',
    'groups'
  from public.erp_item_groups g
  where g.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'الأصناف' or p_area = 'فئات الأصناف')
    and g.id in (select start_id from group_walk where has_cycle))

  union all

  select
    'purchase:' || d.id::text || ':accounting',
    'المشتريات',
    d.id,
    d.document_number,
    d.document_date,
    'القيد المحاسبي غير موجود',
    'تحذير',
    'PURCHASE_ACCOUNTING_MISSING',
    'المستند المخزني مرحّل ولم يُنشأ له قيد أستاذ عام عبر خريطة الحسابات التشغيلية.',
    'purchases'
  from public.erp_purchase_documents d
  where d.company_id = p_company_id and d.status = 'posted'
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and d.document_type in ('receipt','invoice','return')
    and (p_area = 'كل الحركات' or p_area = 'المشتريات' or p_area = 'الموردون')
    and not exists (
      select 1 from public.erp_journal_entries j
      where j.company_id = d.company_id and j.source_type = 'purchase_accounting'
        and j.source_id = d.id and j.status = 'posted'
    )

  union all

  select
    'sale:' || d.id::text || ':accounting',
    'المبيعات',
    d.id,
    d.document_number,
    d.document_date,
    'القيد المحاسبي غير موجود',
    'تحذير',
    'SALE_ACCOUNTING_MISSING',
    'المستند المخزني مرحّل ولم يُنشأ له قيد أستاذ عام عبر خريطة الحسابات التشغيلية.',
    'sales'
  from public.erp_sales_documents d
  where d.company_id = p_company_id and d.status = 'posted'
    and (p_start_date is null or d.document_date >= p_start_date)
    and (p_end_date is null or d.document_date <= p_end_date)
    and d.document_type in ('delivery','invoice','return')
    and (p_area = 'كل الحركات' or p_area = 'المبيعات' or p_area = 'العملاء')
    and not exists (
      select 1 from public.erp_journal_entries j
      where j.company_id = d.company_id and j.source_type = 'sales_accounting'
        and j.source_id = d.id and j.status = 'posted'
    )

  union all

  select
    'company:' || p_company_id::text || ':operational_account_mapping',
    'المحاسبة التشغيلية',
    null::uuid,
    null::text,
    null::date,
    'خريطة الحسابات التشغيلية غير معدة',
    'تحذير',
    'OPERATIONAL_ACCOUNT_MAPPING_MISSING',
    'لم يتم إعداد حسابات العملاء والموردين والإيرادات والمخزون وتكلفة المبيعات لهذه الشركة.',
    'operational_account_mappings'
  where (p_area = 'كل الحركات' or p_area = 'المحاسبة التشغيلية')
    and not exists (
      select 1 from public.erp_operational_account_mappings m where m.company_id = p_company_id
    )

  union all

  select distinct
    'company:' || m.company_id::text || ':operational_account_mapping_invalid',
    'المحاسبة التشغيلية',
    m.id,
    'خريطة الحسابات',
    null::date,
    'حساب مرتبط غير صالح',
    'خطأ',
    'OPERATIONAL_ACCOUNT_MAPPING_INVALID_ACCOUNT',
    'تحتوي خريطة الحسابات التشغيلية على حساب مفقود أو غير نشط أو غير قابل للترحيل أو يتبع شركة أخرى.',
    'operational_account_mappings'
  from public.erp_operational_account_mappings m
  cross join lateral unnest(array[
    m.accounts_receivable_account_id,
    m.accounts_payable_account_id,
    m.sales_revenue_account_id,
    m.sales_returns_account_id,
    m.inventory_account_id,
    m.cost_of_goods_sold_account_id,
    m.purchase_return_variance_account_id,
    m.sales_tax_payable_account_id,
    m.purchase_tax_credit_account_id
  ]) as mapped(account_id)
  left join public.erp_accounts a on a.id = mapped.account_id
  where m.company_id = p_company_id
    and (p_area = 'كل الحركات' or p_area = 'المحاسبة التشغيلية')
    and mapped.account_id is not null
    and (a.id is null or a.company_id <> m.company_id or not a.is_active or not a.is_postable)

  order by document_date nulls last, area, document_number;
end;
$$;

revoke all on function public.erp_run_movement_audit(uuid,date,date,text) from public, anon;
grant execute on function public.erp_run_movement_audit(uuid,date,date,text) to authenticated;
comment on function public.erp_run_movement_audit(uuid,date,date,text) is
  'Read-only integrity audit for accounting, inventory, sales, purchases, cash vouchers, employee attendance, leave and payroll tables installed in the ERP schema.';
