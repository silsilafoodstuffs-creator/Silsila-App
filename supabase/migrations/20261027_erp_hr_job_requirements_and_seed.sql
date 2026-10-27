-- Silsila HR structure, job grades, and job-specific hiring document requirements.
create table if not exists public.erp_hr_job_grades (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 grade_code text not null, name_ar text not null, name_en text not null default '', rank_order integer not null default 1,
 is_active boolean not null default true, created_at timestamptz not null default now(), unique(company_id, grade_code)
);
alter table public.erp_hr_jobs
 add column if not exists grade_id uuid references public.erp_hr_job_grades(id) on delete set null,
 add column if not exists min_qualification text not null default 'إعدادية',
 add column if not exists min_license_class text not null default '',
 add column if not exists requires_photo boolean not null default true,
 add column if not exists requires_birth_certificate boolean not null default true,
 add column if not exists requires_qualification_certificate boolean not null default true,
 add column if not exists requires_work_card boolean not null default true,
 add column if not exists requires_insurance_printout boolean not null default true,
 add column if not exists requires_military_service boolean not null default false,
 add column if not exists requires_criminal_record boolean not null default true,
 add column if not exists requires_trust_receipt boolean not null default false,
 add column if not exists requires_health_certificate boolean not null default false,
 add column if not exists requires_driving_license boolean not null default false,
 add column if not exists requires_id_copy boolean not null default true,
 add column if not exists requires_bank_account boolean not null default false;
alter table public.erp_hr_job_grades enable row level security;
grant select, insert, update, delete on public.erp_hr_job_grades to authenticated;
drop policy if exists erp_hr_job_grades_read_company on public.erp_hr_job_grades;
drop policy if exists erp_hr_job_grades_insert_manager on public.erp_hr_job_grades;
drop policy if exists erp_hr_job_grades_update_manager on public.erp_hr_job_grades;
drop policy if exists erp_hr_job_grades_delete_admin on public.erp_hr_job_grades;
create policy erp_hr_job_grades_read_company on public.erp_hr_job_grades for select to authenticated using (public.erp_user_can_access_company(company_id));
create policy erp_hr_job_grades_insert_manager on public.erp_hr_job_grades for insert to authenticated with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
create policy erp_hr_job_grades_update_manager on public.erp_hr_job_grades for update to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[])) with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));
create policy erp_hr_job_grades_delete_admin on public.erp_hr_job_grades for delete to authenticated using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));
do $$
declare c record; r record; p uuid; g uuid;
begin
 for c in select id from public.erp_companies loop
  for r in select * from (values
('GRD-001', 'رئيس مجلس الإدارة', 'Chairman', 1),
('GRD-002', 'مدير تنفيذي', 'Executive Director', 2),
('GRD-003', 'مدير عام', 'General Manager', 3),
('GRD-004', 'مدير إدارة', 'Department Manager', 4),
('GRD-005', 'مدير فرع', 'Branch Manager', 5),
('GRD-006', 'رئيس قسم', 'Section Head', 6),
('GRD-007', 'مشرف', 'Supervisor', 7),
('GRD-008', 'أخصائي أول', 'Senior Specialist', 8),
('GRD-009', 'أخصائي', 'Specialist', 9),
('GRD-010', 'محاسب / إداري', 'Accountant / Administrator', 10),
('GRD-011', 'مندوب / فني', 'Representative / Technician', 11),
('GRD-012', 'عامل / مساعد', 'Worker / Assistant', 12),
('GRD-013', 'سائق', 'Driver', 13),
('GRD-014', 'عمالة يومية', 'Daily Worker', 14)
  ) v(code,ar,en,rnk) loop
   insert into public.erp_hr_job_grades(company_id,grade_code,name_ar,name_en,rank_order) values(c.id,r.code,r.ar,r.en,r.rnk)
   on conflict(company_id,grade_code) do update set name_ar=excluded.name_ar,name_en=excluded.name_en,rank_order=excluded.rank_order;
  end loop;
  for r in select * from (values
('AUD-001', 'المراجعة والرقابة الداخلية', 'Internal Audit and Control', 'directorate'),
('BRN-001', 'إدارة الفروع', 'Branch Management', 'directorate'),
('CRD-001', 'الائتمان والتحصيل', 'Credit and Collections', 'directorate'),
('CUS-001', 'خدمة العملاء وإدارة الطلبات', 'Customer Service and Orders', 'directorate'),
('DAT-001', 'تحليل البيانات والتخطيط', 'Data and Planning', 'directorate'),
('DIR-001', 'الإدارة العليا', 'Executive Management', 'directorate'),
('EXP-001', 'التصدير والاستيراد', 'Import and Export', 'directorate'),
('FIN-001', 'الحسابات والمالية', 'Finance and Accounting', 'directorate'),
('FLT-001', 'النقل والأسطول', 'Transport and Fleet', 'directorate'),
('HR-001', 'الموارد البشرية والشؤون الإدارية', 'Human Resources and Administration', 'directorate'),
('IT-001', 'تقنية المعلومات والتحول الرقمي', 'IT and Digital Transformation', 'directorate'),
('LEG-001', 'الشؤون القانونية والامتثال', 'Legal and Compliance', 'directorate'),
('LOG-001', 'اللوجستيات والتوزيع', 'Logistics and Distribution', 'directorate'),
('MKT-001', 'التسويق والتجارة الإلكترونية', 'Marketing and E-commerce', 'directorate'),
('MNT-001', 'الصيانة والمرافق', 'Maintenance and Facilities', 'directorate'),
('MOV-001', 'الحركة', 'Fleet Operations', 'department'),
('PRC-001', 'التسعير والعروض التجارية', 'Pricing and Trade Offers', 'directorate'),
('PRD-001', 'تطوير المنتجات والعلامات الخاصة', 'Product and Private Label', 'directorate'),
('PUR-001', 'المشتريات والتوريد', 'Purchasing and Procurement', 'directorate'),
('QAL-001', 'الجودة وسلامة الغذاء', 'Quality and Food Safety', 'directorate'),
('SAL-001', 'المبيعات وتطوير الأعمال', 'Sales and Business Development', 'directorate'),
('SEC-001', 'الأمن والسلامة', 'Security and Safety', 'directorate'),
('WH-001', 'المخازن وإدارة المخزون', 'Warehousing and Inventory', 'directorate')
  ) v(code,ar,en,lev) loop
   insert into public.erp_hr_departments(company_id,department_code,name_ar,name_en,department_level,parent_id) values(c.id,r.code,r.ar,r.en,r.lev,null)
   on conflict(company_id,department_code) do update set name_ar=excluded.name_ar,name_en=excluded.name_en,department_level=excluded.department_level;
  end loop;
  for r in select * from (values
('AUD-SEC-01', 'مراجعة المخزون والمبيعات', 'Stock and Sales Audit', 'section', 'AUD-001'),
('AUD-SEC-02', 'الرقابة على الصلاحيات والإجراءات', 'Process and Access Control', 'section', 'AUD-001'),
('BRN-SEC-01', 'تشغيل الفروع', 'Branch Operations', 'section', 'BRN-001'),
('BRN-SEC-02', 'متابعة أداء الفروع', 'Branch Performance', 'section', 'BRN-001'),
('CRD-SEC-01', 'مراجعة حدود الائتمان', 'Credit Limit Review', 'section', 'CRD-001'),
('CRD-SEC-02', 'التحصيل ومتابعة المديونيات', 'Collections and Receivables', 'section', 'CRD-001'),
('CUS-SEC-01', 'استقبال الطلبات', 'Order Intake', 'section', 'CUS-001'),
('CUS-SEC-02', 'الشكاوى وخدمة ما بعد البيع', 'Complaints and After Sales', 'section', 'CUS-001'),
('DAT-SEC-01', 'التقارير ومؤشرات الأداء', 'Reporting and KPIs', 'section', 'DAT-001'),
('DAT-SEC-02', 'تخطيط الطلب والمخزون', 'Demand and Inventory Planning', 'section', 'DAT-001'),
('DIR-SEC-CENTRAL', 'الإدارة المركزية', 'Central Administration', 'department', 'DIR-001'),
('EXP-SEC-01', 'الاستيراد والتخليص الجمركي', 'Import and Customs', 'section', 'EXP-001'),
('EXP-SEC-02', 'التصدير', 'Export', 'section', 'EXP-001'),
('FIN-SEC-01', 'الحسابات العامة', 'General Accounting', 'section', 'FIN-001'),
('FIN-SEC-02', 'الخزينة والبنوك', 'Treasury and Banks', 'section', 'FIN-001'),
('FIN-SEC-03', 'حسابات العملاء والموردين', 'Customer and Supplier Accounts', 'section', 'FIN-001'),
('FIN-SEC-04', 'الضرائب والفواتير الإلكترونية', 'Tax and E-Invoicing', 'section', 'FIN-001'),
('FLT-SEC-01', 'السائقون ومساعدوهم', 'Drivers and Helpers', 'section', 'FLT-001'),
('FLT-SEC-02', 'صيانة المركبات والترخيص', 'Vehicle Maintenance and Licensing', 'section', 'FLT-001'),
('HR-SEC-01', 'شؤون العاملين والملفات', 'Personnel and Employee Files', 'section', 'HR-001'),
('HR-SEC-02', 'التوظيف والاختيار', 'Recruitment and Selection', 'section', 'HR-001'),
('HR-SEC-03', 'التدريب وتقييم الأداء', 'Training and Performance', 'section', 'HR-001'),
('HR-SEC-04', 'الرواتب والتأمينات', 'Payroll and Social Insurance', 'section', 'HR-001'),
('HR-SEC-05', 'الشؤون الإدارية والخدمات', 'Administration and Services', 'section', 'HR-001'),
('IT-SEC-01', 'الدعم الفني والأجهزة', 'IT Support and Devices', 'section', 'IT-001'),
('IT-SEC-02', 'الأنظمة وقواعد البيانات', 'Systems and Databases', 'section', 'IT-001'),
('IT-SEC-03', 'التجارة الإلكترونية والربط', 'E-commerce and Integrations', 'section', 'IT-001'),
('LEG-SEC-01', 'العقود والتراخيص', 'Contracts and Licenses', 'section', 'LEG-001'),
('LEG-SEC-02', 'الامتثال وحماية البيانات', 'Compliance and Data Protection', 'section', 'LEG-001'),
('LOG-SEC-01', 'تخطيط التوزيع وخطوط السير', 'Distribution Planning and Routes', 'section', 'LOG-001'),
('LOG-SEC-02', 'تسليمات العملاء', 'Customer Deliveries', 'section', 'LOG-001'),
('LOG-SEC-03', 'متابعة الشحنات وشركات النقل', 'Shipment and Carrier Tracking', 'section', 'LOG-001'),
('MKT-SEC-01', 'التسويق الرقمي والمحتوى', 'Digital Marketing and Content', 'section', 'MKT-001'),
('MKT-SEC-02', 'التصميم والإعلانات', 'Design and Advertising', 'section', 'MKT-001'),
('MKT-SEC-03', 'العروض والترويج التجاري', 'Trade Promotion', 'section', 'MKT-001'),
('MNT-SEC-01', 'صيانة المباني والمرافق', 'Facilities Maintenance', 'section', 'MNT-001'),
('MNT-SEC-02', 'صيانة معدات المخازن', 'Warehouse Equipment Maintenance', 'section', 'MNT-001'),
('MOV-SEC-01', 'السائقون والأسطول', 'Drivers and Fleet', 'section', 'MOV-001'),
('MOV-SEC-02', 'خطوط السير والتوزيع', 'Routes and Distribution', 'section', 'MOV-001'),
('PRC-SEC-01', 'التسعير وهوامش الربح', 'Pricing and Margins', 'section', 'PRC-001'),
('PRC-SEC-02', 'إدارة الخصومات والعروض', 'Discounts and Offers', 'section', 'PRC-001'),
('PRD-SEC-01', 'تطوير الأصناف والعلامات الخاصة', 'Product Development and Private Label', 'section', 'PRD-001'),
('PUR-SEC-01', 'شراء المواد الغذائية الجافة', 'Dry Food Purchasing', 'section', 'PUR-001'),
('PUR-SEC-02', 'شراء المجمدات والمبردات', 'Frozen and Chilled Purchasing', 'section', 'PUR-001'),
('PUR-SEC-03', 'الموردون والتعاقدات', 'Suppliers and Contracts', 'section', 'PUR-001'),
('PUR-SEC-04', 'تخطيط الاحتياجات وأوامر الشراء', 'Replenishment and Purchase Orders', 'section', 'PUR-001'),
('QAL-SEC-01', 'فحص الجودة والاستلام', 'Quality Inspection', 'section', 'QAL-001'),
('QAL-SEC-02', 'سلامة الغذاء والصلاحية', 'Food Safety and Expiry', 'section', 'QAL-001'),
('SAL-SEC-01', 'مبيعات الجملة', 'Wholesale Sales', 'section', 'SAL-001'),
('SAL-SEC-02', 'مبيعات نصف الجملة', 'Semi-Wholesale Sales', 'section', 'SAL-001'),
('SAL-SEC-03', 'مبيعات التجزئة والسلاسل', 'Retail and Chains Sales', 'section', 'SAL-001'),
('SAL-SEC-04', 'المبيعات الهاتفية والرقمية', 'Telesales and Digital Sales', 'section', 'SAL-001'),
('SAL-SEC-05', 'إدارة الحسابات الرئيسية', 'Key Accounts', 'section', 'SAL-001'),
('SEC-SEC-01', 'الأمن ومراقبة الدخول', 'Security and Access Control', 'section', 'SEC-001'),
('SEC-SEC-02', 'الصحة والسلامة المهنية', 'Occupational Health and Safety', 'section', 'SEC-001'),
('WH-SEC-01', 'استلام وفحص الوارد', 'Receiving and Inbound Inspection', 'section', 'WH-001'),
('WH-SEC-02', 'التخزين وترتيب المواقع', 'Storage and Putaway', 'section', 'WH-001'),
('WH-SEC-03', 'تجهيز الطلبات والتعبئة', 'Picking and Packing', 'section', 'WH-001'),
('WH-SEC-04', 'الجرد ومراقبة المخزون', 'Stocktaking and Inventory Control', 'section', 'WH-001'),
('WH-SEC-05', 'المرتجعات والتالف والصلاحية', 'Returns, Damage and Expiry', 'section', 'WH-001')
  ) v(code,ar,en,lev,parent_code) loop
   select id into p from public.erp_hr_departments where company_id=c.id and department_code=r.parent_code;
   insert into public.erp_hr_departments(company_id,department_code,name_ar,name_en,department_level,parent_id) values(c.id,r.code,r.ar,r.en,r.lev,p)
   on conflict(company_id,department_code) do update set name_ar=excluded.name_ar,name_en=excluded.name_en,department_level=excluded.department_level,parent_id=excluded.parent_id;
  end loop;
  for r in select * from (values
('JOB-001', 'مدير عام', 'General Manager', 'DIR-001', 'GRD-003', 'جامعية', '', true, true, true, true, true, true, true, true, true, false, false, true),
('JOB-002', 'مدير مالي', 'Finance Manager', 'FIN-001', 'GRD-004', 'جامعية', '', true, true, true, true, true, true, true, true, true, false, false, true),
('JOB-003', 'محاسب عام', 'General Accountant', 'FIN-SEC-01', 'GRD-010', 'تجارة / جامعية', '', true, true, true, true, true, true, true, true, false, false, false, true),
('JOB-004', 'أمين خزينة', 'Treasury Cashier', 'FIN-SEC-02', 'GRD-010', 'تجارة / ثانوية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-005', 'مدير موارد بشرية', 'HR Manager', 'HR-001', 'GRD-004', 'جامعية', '', true, true, true, true, true, true, true, true, true, false, false, true),
('JOB-006', 'أخصائي موارد بشرية', 'HR Specialist', 'HR-SEC-01', 'GRD-009', 'جامعية', '', true, true, true, true, true, true, true, true, false, false, false, true),
('JOB-007', 'مسؤول توظيف', 'Recruitment Officer', 'HR-SEC-02', 'GRD-009', 'جامعية', '', true, true, true, true, true, true, true, true, false, false, false, true),
('JOB-008', 'مسؤول رواتب وتأمينات', 'Payroll and Insurance Officer', 'HR-SEC-04', 'GRD-010', 'تجارة / جامعية', '', true, true, true, true, true, true, true, true, false, false, false, true),
('JOB-009', 'مدير مشتريات', 'Purchasing Manager', 'PUR-001', 'GRD-004', 'جامعية', '', true, true, true, true, true, true, true, true, true, false, false, true),
('JOB-010', 'أخصائي مشتريات', 'Purchasing Specialist', 'PUR-SEC-01', 'GRD-009', 'ثانوية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-011', 'مسؤول متابعة الموردين', 'Supplier Relations Officer', 'PUR-SEC-03', 'GRD-009', 'ثانوية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-012', 'مدير مبيعات', 'Sales Manager', 'SAL-001', 'GRD-004', 'جامعية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-013', 'مشرف مبيعات', 'Sales Supervisor', 'SAL-001', 'GRD-007', 'ثانوية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-014', 'مندوب مبيعات جملة', 'Wholesale Sales Representative', 'SAL-SEC-01', 'GRD-011', 'ثانوية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-015', 'مندوب مبيعات نصف جملة', 'Semi-Wholesale Sales Representative', 'SAL-SEC-02', 'GRD-011', 'إعدادية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-016', 'مندوب مبيعات هاتفي', 'Telesales Representative', 'SAL-SEC-04', 'GRD-011', 'ثانوية', '', true, true, true, true, true, true, false, true, false, false, false, true),
('JOB-017', 'مسؤول خدمة عملاء', 'Customer Service Officer', 'CUS-SEC-01', 'GRD-009', 'ثانوية', '', true, true, true, true, true, true, false, true, false, false, false, true),
('JOB-018', 'مدير تسويق', 'Marketing Manager', 'MKT-001', 'GRD-004', 'جامعية', '', true, true, true, true, true, true, false, true, false, false, false, true),
('JOB-019', 'مسؤول تسويق رقمي', 'Digital Marketing Officer', 'MKT-SEC-01', 'GRD-009', 'جامعية', '', true, true, true, true, true, true, false, true, false, false, false, true),
('JOB-020', 'مدير مخازن', 'Warehouse Manager', 'WH-001', 'GRD-004', 'ثانوية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-021', 'مشرف مخزن', 'Warehouse Supervisor', 'WH-001', 'GRD-007', 'ثانوية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-022', 'أمين مخزن', 'Storekeeper', 'WH-SEC-02', 'GRD-011', 'إعدادية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-023', 'مسؤول استلام وفحص', 'Receiving and Inspection Clerk', 'WH-SEC-01', 'GRD-011', 'إعدادية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-024', 'عامل تجهيز طلبات', 'Order Picker', 'WH-SEC-03', 'GRD-012', 'ابتدائية', '', true, false, true, false, true, true, false, true, false, false, false, false),
('JOB-025', 'مدير توزيع ولوجستيات', 'Distribution and Logistics Manager', 'LOG-001', 'GRD-004', 'جامعية', '', true, true, true, true, true, true, true, true, true, false, false, true),
('JOB-026', 'مخطط خطوط سير', 'Route Planner', 'LOG-SEC-01', 'GRD-009', 'ثانوية', '', true, true, true, true, true, true, false, true, false, false, false, true),
('JOB-027', 'مندوب تسليم وتحصيل', 'Delivery and Collection Representative', 'LOG-SEC-02', 'GRD-011', 'ثانوية', 'مهنية', true, true, true, true, true, true, false, true, true, false, true, true),
('JOB-028', 'مدير أسطول', 'Fleet Manager', 'FLT-001', 'GRD-004', 'جامعية', '', true, true, true, true, true, true, true, true, true, false, true, true),
('JOB-029', 'سائق سيارة توزيع', 'Distribution Driver', 'FLT-SEC-01', 'GRD-013', 'إعدادية', 'ثالثة مهنية', true, true, true, true, true, true, true, true, true, true, true, false),
('JOB-030', 'مساعد سائق', 'Driver Helper', 'FLT-SEC-01', 'GRD-012', 'ابتدائية', '', true, false, true, false, true, true, false, true, false, false, false, false),
('JOB-031', 'مسؤول جودة وسلامة غذاء', 'Food Quality Officer', 'QAL-SEC-01', 'GRD-009', 'جامعية', '', true, true, true, true, true, true, true, true, false, true, false, true),
('JOB-032', 'مسؤول صحة وسلامة مهنية', 'HSE Officer', 'SEC-SEC-02', 'GRD-009', 'جامعية', '', true, true, true, true, true, true, true, true, false, true, false, true),
('JOB-033', 'مسؤول تقنية معلومات', 'IT Support Officer', 'IT-SEC-01', 'GRD-009', 'دبلوم فني', '', true, true, true, true, true, true, false, true, false, false, false, true),
('JOB-034', 'محلل بيانات وتقارير', 'Data and Reporting Analyst', 'DAT-SEC-01', 'GRD-009', 'جامعية', '', true, true, true, true, true, true, false, true, false, false, false, true),
('JOB-035', 'مسؤول ائتمان وتحصيل', 'Credit and Collections Officer', 'CRD-SEC-02', 'GRD-009', 'تجارة / جامعية', '', true, true, true, true, true, true, false, true, true, false, false, true),
('JOB-036', 'مندوب استيراد وتخليص', 'Import and Customs Representative', 'EXP-SEC-01', 'GRD-011', 'جامعية', '', true, true, true, true, true, true, true, true, false, false, false, true),
('JOB-037', 'عامل نظافة وخدمات', 'Cleaning and Facilities Worker', 'MNT-SEC-01', 'GRD-012', 'ابتدائية', '', true, false, true, false, true, true, false, true, false, false, false, false),
('JOB-038', 'فرد أمن', 'Security Officer', 'SEC-SEC-01', 'GRD-012', 'إعدادية', '', true, false, true, true, true, true, true, true, false, false, false, false),
('JOB-039', 'مراجع داخلي', 'Internal Auditor', 'AUD-SEC-01', 'GRD-009', 'جامعية', '', true, true, true, true, true, true, true, true, false, false, false, true),
('JOB-040', 'مدير فرع توزيع', 'Distribution Branch Manager', 'BRN-001', 'GRD-005', 'جامعية', '', true, true, true, true, true, true, true, true, true, false, false, true)
  ) v(code,ar,en,dept_code,grade_code,qual,lic,photo,idcopy,birth,qualification,workcard,insurance,military,criminal,trust,health,driver,bank) loop
   select id into p from public.erp_hr_departments where company_id=c.id and department_code=r.dept_code;
   select id into g from public.erp_hr_job_grades where company_id=c.id and grade_code=r.grade_code;
   insert into public.erp_hr_jobs(company_id,job_code,name_ar,name_en,department_id,grade_id,min_qualification,min_license_class,requires_photo,requires_id_copy,requires_birth_certificate,requires_qualification_certificate,requires_work_card,requires_insurance_printout,requires_military_service,requires_criminal_record,requires_trust_receipt,requires_health_certificate,requires_driving_license,requires_bank_account,is_active)
   values(c.id,r.code,r.ar,r.en,p,g,r.qual,r.lic,r.photo,r.idcopy,r.birth,r.qualification,r.workcard,r.insurance,r.military,r.criminal,r.trust,r.health,r.driver,r.bank,true)
   on conflict(company_id,job_code) do update set name_ar=excluded.name_ar,name_en=excluded.name_en,department_id=excluded.department_id,grade_id=excluded.grade_id,min_qualification=excluded.min_qualification,min_license_class=excluded.min_license_class,requires_photo=excluded.requires_photo,requires_id_copy=excluded.requires_id_copy,requires_birth_certificate=excluded.requires_birth_certificate,requires_qualification_certificate=excluded.requires_qualification_certificate,requires_work_card=excluded.requires_work_card,requires_insurance_printout=excluded.requires_insurance_printout,requires_military_service=excluded.requires_military_service,requires_criminal_record=excluded.requires_criminal_record,requires_trust_receipt=excluded.requires_trust_receipt,requires_health_certificate=excluded.requires_health_certificate,requires_driving_license=excluded.requires_driving_license,requires_bank_account=excluded.requires_bank_account;
  end loop;
 end loop;
end $$;
