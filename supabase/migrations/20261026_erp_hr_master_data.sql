-- Ensure the employee master exists even when the earlier standalone HR SQL was not applied.
create table if not exists public.erp_employees (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete restrict,
 branch_id uuid references public.erp_branches(id) on delete restrict,
 employee_code text not null, full_name text not null, phone text, email text, job_title text,
 department_name text, hire_date date,
 employment_status text not null default 'active' check (employment_status in ('active','on_leave','suspended','terminated')),
 base_salary numeric(14,2) not null default 0 check (base_salary >= 0),
 national_id_last4 text, notes text, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id, employee_code), check(length(trim(full_name)) > 0)
);
alter table public.erp_employees enable row level security;
create table if not exists public.erp_hr_departments (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 department_code text not null, name_ar text not null, name_en text not null default '', parent_id uuid references public.erp_hr_departments(id) on delete set null,
 department_level text not null default 'department' check(department_level in ('directorate','department','section')), is_active boolean not null default true, created_at timestamptz not null default now(), unique(company_id,department_code));
create table if not exists public.erp_hr_jobs (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 job_code text not null, name_ar text not null, name_en text not null default '', department_id uuid references public.erp_hr_departments(id) on delete set null,
 is_active boolean not null default true, created_at timestamptz not null default now(), unique(company_id,job_code));
create table if not exists public.erp_hr_work_locations (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 location_code text not null, name_ar text not null, location_type text not null default 'branch' check(location_type in ('central','branch')),
 address text, is_active boolean not null default true, created_at timestamptz not null default now(), unique(company_id,location_code));
alter table public.erp_employees add column if not exists full_name_en text, add column if not exists country text not null default 'مصر',
 add column if not exists governorate text, add column if not exists district text, add column if not exists locality text,
 add column if not exists address text, add column if not exists map_url text, add column if not exists mobile_1 text,
 add column if not exists mobile_2 text, add column if not exists work_mobile_1 text, add column if not exists work_mobile_2 text,
 add column if not exists department_id uuid references public.erp_hr_departments(id) on delete set null,
 add column if not exists job_id uuid references public.erp_hr_jobs(id) on delete set null,
 add column if not exists work_location_id uuid references public.erp_hr_work_locations(id) on delete set null;
alter table public.erp_hr_departments enable row level security; alter table public.erp_hr_jobs enable row level security; alter table public.erp_hr_work_locations enable row level security;
do $$ declare t text; begin foreach t in array array['erp_hr_departments','erp_hr_jobs','erp_hr_work_locations'] loop
 execute format('drop policy if exists %I on public.%I',t||'_member_access',t);
 execute format('create policy %I on public.%I for all to authenticated using (exists (select 1 from public.erp_company_members m where m.company_id = %I.company_id and m.user_id = auth.uid() and coalesce(m.is_active,true))) with check (exists (select 1 from public.erp_company_members m where m.company_id = %I.company_id and m.user_id = auth.uid() and coalesce(m.is_active,true)))',t||'_member_access',t,t,t);
 end loop; end $$;
do $$ declare c record; d record; dep uuid; begin
 for c in select id from public.erp_companies loop
 for d in select * from (values
 ('DIR-001','الإدارة العليا','Executive Management','directorate'),('HR-001','الموارد البشرية','Human Resources','department'),('PUR-001','المشتريات','Purchasing','department'),('LOG-001','اللوجيستيك','Logistics','department'),('SAL-001','المبيعات','Sales','department'),('MKT-001','التسويق','Marketing','department'),('CRD-001','الائتمان','Credit','department'),('MOV-001','الحركة','Fleet Operations','department'),('IT-001','تقنية المعلومات','Information Technology','department')
 ) v(code,ar,en,lev) loop insert into public.erp_hr_departments(company_id,department_code,name_ar,name_en,department_level) values(c.id,d.code,d.ar,d.en,d.lev) on conflict(company_id,department_code) do nothing; end loop;
 for d in select * from (values
 ('HR-SEC-01','شؤون العاملين','Personnel Affairs','HR-001'),('HR-SEC-02','التوظيف والاختيار','Recruitment','HR-001'),('HR-SEC-03','التدريب والتطوير','Training and Development','HR-001'),('HR-SEC-04','الأجور والمزايا','Payroll and Benefits','HR-001'),
 ('PUR-SEC-01','شراء المواد الغذائية','Food Purchasing','PUR-001'),('PUR-SEC-02','تخطيط المشتريات','Procurement Planning','PUR-001'),('LOG-SEC-01','إدارة المخازن','Warehouse Management','LOG-001'),('LOG-SEC-02','التجهيز والتعبئة','Picking and Packing','LOG-001'),
 ('SAL-SEC-01','مبيعات الجملة','Wholesale Sales','SAL-001'),('SAL-SEC-02','مبيعات التجزئة','Retail Sales','SAL-001'),('SAL-SEC-03','خدمة العملاء والطلبات','Customer Orders','SAL-001'),('MKT-SEC-01','التسويق الرقمي','Digital Marketing','MKT-001'),
 ('CRD-SEC-01','تحليل الائتمان','Credit Analysis','CRD-001'),('MOV-SEC-01','السائقون والأسطول','Drivers and Fleet','MOV-001'),('MOV-SEC-02','خطوط السير والتوزيع','Routes and Distribution','MOV-001'),('IT-SEC-01','الدعم الفني','IT Support','IT-001'),('IT-SEC-02','الأنظمة وقواعد البيانات','Systems and Databases','IT-001')
 ) v(code,ar,en,parent_code) loop select id into dep from public.erp_hr_departments where company_id=c.id and department_code=d.parent_code;
 insert into public.erp_hr_departments(company_id,department_code,name_ar,name_en,parent_id,department_level) values(c.id,d.code,d.ar,d.en,dep,'section') on conflict(company_id,department_code) do nothing; end loop;
 for d in select * from (values
 ('JOB-001','مدير عام','General Manager','DIR-001'),('JOB-002','مدير موارد بشرية','HR Manager','HR-001'),('JOB-003','أخصائي موارد بشرية','HR Specialist','HR-SEC-01'),('JOB-004','مسؤول توظيف','Recruiter','HR-SEC-02'),('JOB-005','محاسب رواتب','Payroll Accountant','HR-SEC-04'),
 ('JOB-006','مدير مشتريات','Purchasing Manager','PUR-001'),('JOB-007','أخصائي مشتريات','Purchasing Specialist','PUR-SEC-01'),('JOB-008','مدير لوجيستيك','Logistics Manager','LOG-001'),('JOB-009','مدير مخازن','Warehouse Manager','LOG-SEC-01'),('JOB-010','أمين مخزن','Storekeeper','LOG-SEC-01'),('JOB-011','عامل تجهيز طلبات','Order Picker','LOG-SEC-02'),
 ('JOB-012','مدير مبيعات','Sales Manager','SAL-001'),('JOB-013','مشرف مبيعات','Sales Supervisor','SAL-001'),('JOB-014','مندوب مبيعات داخلي','Inside Sales Representative','SAL-SEC-01'),('JOB-015','مندوب مبيعات خارجي','Outside Sales Representative','SAL-SEC-01'),('JOB-016','مندوب مبيعات هاتفي','Telesales Representative','SAL-SEC-03'),('JOB-017','مندوب توزيع وتحصيل','Distribution Representative','SAL-SEC-02'),('JOB-018','مندوب عملاء رئيسيين','Key Account Representative','SAL-SEC-01'),('JOB-019','مسؤول خدمة عملاء','Customer Service Officer','SAL-SEC-03'),
 ('JOB-020','مدير تسويق','Marketing Manager','MKT-001'),('JOB-021','أخصائي تسويق رقمي','Digital Marketing Specialist','MKT-SEC-01'),('JOB-022','مسؤول ائتمان','Credit Officer','CRD-SEC-01'),('JOB-023','مدير حركة','Fleet Manager','MOV-001'),('JOB-024','سائق توزيع','Delivery Driver','MOV-SEC-01'),('JOB-025','مساعد سائق','Driver Assistant','MOV-SEC-01'),('JOB-026','مراقب خطوط سير','Route Controller','MOV-SEC-02'),('JOB-027','أمين خزينة','Treasury Cashier','DIR-001'),('JOB-028','محاسب عام','General Accountant','DIR-001'),('JOB-029','محاسب عملاء','Accounts Receivable Accountant','DIR-001'),('JOB-030','محاسب موردين','Accounts Payable Accountant','PUR-001'),('JOB-031','مدير تقنية المعلومات','IT Manager','IT-001'),('JOB-032','دعم فني','IT Support Specialist','IT-SEC-01'),('JOB-033','مسؤول قواعد بيانات','Database Administrator','IT-SEC-02')
 ) v(code,ar,en,dept_code) loop select id into dep from public.erp_hr_departments where company_id=c.id and department_code=d.dept_code;
 insert into public.erp_hr_jobs(company_id,job_code,name_ar,name_en,department_id) values(c.id,d.code,d.ar,d.en,dep) on conflict(company_id,job_code) do nothing; end loop;
 insert into public.erp_hr_work_locations(company_id,location_code,name_ar,location_type) values(c.id,'LOC-001','الإدارة المركزية','central') on conflict(company_id,location_code) do nothing;
 end loop; end $$;
