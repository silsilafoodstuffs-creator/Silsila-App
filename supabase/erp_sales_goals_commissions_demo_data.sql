-- Silsila ERP: sales targets, commission rules, geographic directory and clearly-labelled demo data.
-- Prerequisites: apply erp_schema.sql and erp_operations_schema.sql first.
-- This migration creates structures only; it does NOT import private competitor data,
-- scrape Google Maps/social networks, or pretend demo records are verified businesses.
-- Run from Supabase SQL Editor. RLS is enabled without broad client policies by design.

create table if not exists public.erp_geo_areas (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.erp_geo_areas(id) on delete restrict,
  governorate text not null,
  area_name text not null,
  area_kind text not null check (area_kind in ('governorate','city','district','center','village','neighborhood','industrial_zone','market','other')),
  name_ar text not null,
  name_en text,
  postal_code text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  source_name text not null default 'seed_reference',
  source_url text,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(parent_id, area_kind, name_ar)
);

create index if not exists erp_geo_areas_parent_idx on public.erp_geo_areas(parent_id);
create index if not exists erp_geo_areas_governorate_idx on public.erp_geo_areas(governorate, area_kind);

create table if not exists public.erp_sales_representatives (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  rep_code text not null,
  rep_name text not null,
  phone text,
  email text,
  home_area_id uuid references public.erp_geo_areas(id) on delete set null,
  assigned_area_ids uuid[] not null default '{}',
  monthly_sales_target numeric(14,2) not null default 0 check (monthly_sales_target >= 0),
  monthly_collection_target numeric(14,2) not null default 0 check (monthly_collection_target >= 0),
  commission_plan text not null default 'percentage' check (commission_plan in ('percentage','fixed_per_invoice','tiered')),
  default_commission_rate numeric(7,4) not null default 0 check (default_commission_rate >= 0),
  is_demo_data boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, rep_code)
);

create table if not exists public.erp_customer_monthly_goals (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  customer_id uuid not null references public.erp_parties(id) on delete cascade,
  goal_month date not null,
  sales_target numeric(14,2) not null default 0 check (sales_target >= 0),
  collection_target numeric(14,2) not null default 0 check (collection_target >= 0),
  target_orders integer not null default 0 check (target_orders >= 0),
  bonus_rate numeric(7,4) not null default 0 check (bonus_rate >= 0),
  notes text,
  is_demo_data boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, customer_id, goal_month)
);

create table if not exists public.erp_commission_plans (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  plan_code text not null,
  plan_name text not null,
  calculation_basis text not null check (calculation_basis in ('sales_value','collected_value','gross_profit','invoice_count')),
  commission_method text not null check (commission_method in ('percentage','fixed_per_invoice','tiered')),
  flat_rate numeric(7,4) not null default 0 check (flat_rate >= 0),
  fixed_amount numeric(14,2) not null default 0 check (fixed_amount >= 0),
  min_target_percent numeric(7,2) not null default 0 check (min_target_percent >= 0),
  max_commission numeric(14,2),
  effective_from date not null default current_date,
  effective_to date,
  is_demo_data boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, plan_code),
  check (effective_to is null or effective_to >= effective_from)
);

create table if not exists public.erp_commission_tiers (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.erp_commission_plans(id) on delete cascade,
  min_value numeric(14,2) not null default 0 check (min_value >= 0),
  max_value numeric(14,2),
  rate numeric(7,4) not null default 0 check (rate >= 0),
  fixed_amount numeric(14,2) not null default 0 check (fixed_amount >= 0),
  created_at timestamptz not null default now(),
  check (max_value is null or max_value >= min_value),
  unique(plan_id, min_value)
);

create table if not exists public.erp_commission_runs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  representative_id uuid not null references public.erp_sales_representatives(id) on delete restrict,
  plan_id uuid references public.erp_commission_plans(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  eligible_sales numeric(14,2) not null default 0,
  eligible_collections numeric(14,2) not null default 0,
  eligible_gross_profit numeric(14,2) not null default 0,
  eligible_invoice_count integer not null default 0,
  calculated_commission numeric(14,2) not null default 0,
  status text not null default 'draft' check (status in ('draft','reviewed','approved','paid','cancelled')),
  is_demo_data boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);

alter table public.erp_parties
  add column if not exists business_classification text,
  add column if not exists sales_rep_id uuid references public.erp_sales_representatives(id) on delete set null,
  add column if not exists geo_area_id uuid references public.erp_geo_areas(id) on delete set null,
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists is_demo_data boolean not null default false;

alter table public.erp_items
  add column if not exists brand_name text,
  add column if not exists package_description text,
  add column if not exists image_url text,
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists is_demo_data boolean not null default false;

alter table public.erp_sales_documents
  add column if not exists sales_rep_id uuid references public.erp_sales_representatives(id) on delete set null,
  add column if not exists is_demo_data boolean not null default false;

alter table public.erp_purchase_documents
  add column if not exists is_demo_data boolean not null default false;

alter table public.erp_geo_areas enable row level security;
alter table public.erp_sales_representatives enable row level security;
alter table public.erp_customer_monthly_goals enable row level security;
alter table public.erp_commission_plans enable row level security;
alter table public.erp_commission_tiers enable row level security;
alter table public.erp_commission_runs enable row level security;

-- Publicly documented geography seeds: top-level Greater Cairo and a useful starter
-- hierarchy. These are reference areas, not an exhaustive official administrative gazetteer.
insert into public.erp_geo_areas(parent_id,governorate,area_name,area_kind,name_ar,name_en,source_name,source_url,is_verified)
values
(null,'القاهرة','القاهرة','governorate','محافظة القاهرة','Cairo Governorate','CAPMAS / public reference','https://www.capmas.gov.eg/',false),
(null,'الجيزة','الجيزة','governorate','محافظة الجيزة','Giza Governorate','CAPMAS / public reference','https://www.capmas.gov.eg/',false),
(null,'القليوبية','القليوبية','governorate','محافظة القليوبية','Qalyubia Governorate','CAPMAS / public reference','https://www.capmas.gov.eg/',false)
on conflict do nothing;

insert into public.erp_geo_areas(parent_id,governorate,area_name,area_kind,name_ar,name_en,source_name,source_url,is_verified)
select g.id, x.gov, x.area, x.kind, x.name_ar, x.name_en, 'Silsila starter geography', null, false
from (values
('القاهرة','مدينة نصر','district','مدينة نصر','Nasr City'),
('القاهرة','مصر الجديدة','district','مصر الجديدة','Heliopolis'),
('القاهرة','عين شمس','district','عين شمس','Ain Shams'),
('القاهرة','المطرية','district','المطرية','El Matareya'),
('القاهرة','المرج','district','المرج','El Marg'),
('القاهرة','السلام','district','السلام','El Salam'),
('القاهرة','المعادي','district','المعادي','Maadi'),
('القاهرة','حلوان','district','حلوان','Helwan'),
('القاهرة','شبرا','district','شبرا','Shubra'),
('القاهرة','العتبة','market','العتبة','Ataba Market'),
('القاهرة','سوق العبور','market','سوق العبور','Obour Market'),
('الجيزة','الدقي','district','الدقي','Dokki'),
('الجيزة','العجوزة','district','العجوزة','Agouza'),
('الجيزة','فيصل','district','فيصل','Faisal'),
('الجيزة','الهرم','district','الهرم','Haram'),
('الجيزة','إمبابة','district','إمبابة','Imbaba'),
('الجيزة','بولاق الدكرور','district','بولاق الدكرور','Bulaq al-Dakrur'),
('الجيزة','أكتوبر','city','مدينة السادس من أكتوبر','6th of October City'),
('الجيزة','الشيخ زايد','city','مدينة الشيخ زايد','Sheikh Zayed City'),
('القليوبية','شبرا الخيمة','city','شبرا الخيمة','Shubra El-Kheima'),
('القليوبية','بنها','city','بنها','Banha'),
('القليوبية','قليوب','city','قليوب','Qalyub'),
('القليوبية','الخصوص','city','الخصوص','El Khusus'),
('القليوبية','العبور','city','مدينة العبور','Obour City')
) as x(gov,area,kind,name_ar,name_en)
join public.erp_geo_areas g on g.parent_id is null and g.governorate=x.gov and g.area_kind='governorate'
on conflict do nothing;

-- The sample master data is inserted only for the company named below.
-- Change this match to the intended company if the legal/trade name differs.
do $$
declare
  v_company uuid;
  v_branch uuid;
  v_warehouse uuid;
  v_rep uuid;
  v_group uuid;
  v_customer uuid;
  v_supplier uuid;
  v_plan uuid;
  v_item1 uuid;
  v_item2 uuid;
  v_item3 uuid;
  v_area uuid;
  v_doc uuid;
  v_month date := date_trunc('month', current_date)::date;
begin
  select id into v_company
  from public.erp_companies
  where lower(coalesce(trade_name,'')) like '%سلسلة%'
     or lower(coalesce(legal_name,'')) like '%سلسلة%'
  order by created_at
  limit 1;

  if v_company is null then
    raise notice 'Demo seed skipped: create/select the Silsila company in erp_companies first. Geography and schema were created.';
    return;
  end if;

  select id into v_branch from public.erp_branches where company_id=v_company order by is_main desc, created_at limit 1;
  select id into v_warehouse from public.erp_warehouses where company_id=v_company order by created_at limit 1;

  insert into public.erp_item_groups(company_id,group_code,group_name)
  values
  (v_company,'DEMO-OIL','زيوت وسمن - بيانات تجريبية'),
  (v_company,'DEMO-DRY','بقوليات ومكرونة - بيانات تجريبية'),
  (v_company,'DEMO-DRINK','مشروبات - بيانات تجريبية')
  on conflict(company_id,group_code) do update set group_name=excluded.group_name;

  select id into v_group from public.erp_item_groups where company_id=v_company and group_code='DEMO-OIL';
  insert into public.erp_items(company_id,group_id,item_code,item_name,base_unit,purchase_price,sale_price,reorder_level,brand_name,package_description,image_url,source_name,is_demo_data)
  values
  (v_company,v_group,'DEMO-OIL-001','زيت خليط 1 لتر - عينة','زجاجة',48,54,24,'علامة تجريبية','12 زجاجة / كرتونة','https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=480','Silsila demo',true),
  (v_company,v_group,'DEMO-OIL-002','سمن نباتي 1.5 كجم - عينة','عبوة',92,105,12,'علامة تجريبية','6 عبوات / كرتونة','https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=480','Silsila demo',true)
  on conflict(company_id,item_code) do update set item_name=excluded.item_name, purchase_price=excluded.purchase_price, sale_price=excluded.sale_price, image_url=excluded.image_url, is_demo_data=true;

  select id into v_group from public.erp_item_groups where company_id=v_company and group_code='DEMO-DRY';
  insert into public.erp_items(company_id,group_id,item_code,item_name,base_unit,purchase_price,sale_price,reorder_level,brand_name,package_description,image_url,source_name,is_demo_data)
  values
  (v_company,v_group,'DEMO-DRY-001','أرز معبأ 1 كجم - عينة','كيس',28,32,30,'علامة تجريبية','10 أكياس / شوال','https://images.unsplash.com/photo-1586201375761-83865001e31c?w=480','Silsila demo',true)
  on conflict(company_id,item_code) do update set item_name=excluded.item_name, purchase_price=excluded.purchase_price, sale_price=excluded.sale_price, image_url=excluded.image_url, is_demo_data=true;

  select id into v_area from public.erp_geo_areas where name_ar in ('مدينة نصر','الدقي','مدينة العبور') order by case name_ar when 'مدينة نصر' then 1 when 'الدقي' then 2 else 3 end limit 1;

  insert into public.erp_sales_representatives(company_id,rep_code,rep_name,home_area_id,monthly_sales_target,monthly_collection_target,commission_plan,default_commission_rate,is_demo_data)
  values
  (v_company,'DEMO-REP-01','أحمد سامح - مندوب تجريبي',v_area,350000,280000,'tiered',0.015,true),
  (v_company,'DEMO-REP-02','محمود عادل - مندوب تجريبي',v_area,275000,220000,'percentage',0.0125,true),
  (v_company,'DEMO-REP-03','كريم أشرف - مندوب تجريبي',v_area,220000,180000,'fixed_per_invoice',35,true)
  on conflict(company_id,rep_code) do update set rep_name=excluded.rep_name,monthly_sales_target=excluded.monthly_sales_target,monthly_collection_target=excluded.monthly_collection_target,is_demo_data=true;

  select id into v_rep from public.erp_sales_representatives where company_id=v_company and rep_code='DEMO-REP-01';

  insert into public.erp_parties(company_id,party_code,party_name,party_kind,phone,whatsapp,address,governorate,district,credit_limit,opening_balance,business_classification,sales_rep_id,geo_area_id,source_name,is_demo_data)
  values
  (v_company,'DEMO-CUS-001','ماركت النور - عميل تجريبي','customer',null,null,'عنوان تجريبي - مدينة نصر','القاهرة','مدينة نصر',50000,0,'سوبر ماركت',v_rep,v_area,'Silsila demo',true),
  (v_company,'DEMO-CUS-002','بقالة البركة - عميل تجريبي','customer',null,null,'عنوان تجريبي - المرج','القاهرة','المرج',15000,0,'بقالة / كشك',v_rep,v_area,'Silsila demo',true),
  (v_company,'DEMO-CUS-003','تاجر جملة المستقبل - عميل تجريبي','customer',null,null,'عنوان تجريبي - العتبة','القاهرة','العتبة',150000,0,'جملة',v_rep,v_area,'Silsila demo',true),
  (v_company,'DEMO-CUS-004','مؤسسة توريد غذائي - عميل تجريبي','customer',null,null,'عنوان تجريبي - الدقي','الجيزة','الدقي',100000,0,'توريدات مؤسسية / مدارس',v_rep,v_area,'Silsila demo',true),
  (v_company,'DEMO-SUP-001','مورد مواد غذائية تجريبي - أ','supplier',null,null,'عنوان تجريبي - سوق العبور','القليوبية','العبور',0,0,'مورد جملة',null,v_area,'Silsila demo',true),
  (v_company,'DEMO-SUP-002','مورد مشروبات تجريبي - ب','supplier',null,null,'عنوان تجريبي - القاهرة','القاهرة','القاهرة',0,0,'موزع / وكيل',null,v_area,'Silsila demo',true)
  on conflict(company_id,party_code) do update set party_name=excluded.party_name,business_classification=excluded.business_classification,sales_rep_id=excluded.sales_rep_id,is_demo_data=true;

  select id into v_customer from public.erp_parties where company_id=v_company and party_code='DEMO-CUS-001';
  select id into v_supplier from public.erp_parties where company_id=v_company and party_code='DEMO-SUP-001';

  insert into public.erp_customer_monthly_goals(company_id,customer_id,goal_month,sales_target,collection_target,target_orders,bonus_rate,notes,is_demo_data)
  select v_company,p.id,v_month,
         case p.party_code when 'DEMO-CUS-001' then 45000 when 'DEMO-CUS-002' then 18000 when 'DEMO-CUS-003' then 125000 else 70000 end,
         case p.party_code when 'DEMO-CUS-001' then 40000 when 'DEMO-CUS-002' then 16000 when 'DEMO-CUS-003' then 100000 else 60000 end,
         case p.party_code when 'DEMO-CUS-001' then 24 when 'DEMO-CUS-002' then 18 when 'DEMO-CUS-003' then 12 else 8 end,
         0.5,'هدف شهري افتراضي لأغراض تجربة النظام',true
  from public.erp_parties p
  where p.company_id=v_company and p.party_code in ('DEMO-CUS-001','DEMO-CUS-002','DEMO-CUS-003','DEMO-CUS-004')
  on conflict(company_id,customer_id,goal_month) do update set sales_target=excluded.sales_target,collection_target=excluded.collection_target,target_orders=excluded.target_orders,is_demo_data=true;

  insert into public.erp_commission_plans(company_id,plan_code,plan_name,calculation_basis,commission_method,flat_rate,fixed_amount,min_target_percent,is_demo_data)
  values
  (v_company,'DEMO-COM-PCT','عمولة مبيعات تجريبية 1.25%','sales_value','percentage',1.25,0,0,true),
  (v_company,'DEMO-COM-FIX','عمولة ثابتة لكل فاتورة تجريبية','invoice_count','fixed_per_invoice',0,35,0,true),
  (v_company,'DEMO-COM-TIER','عمولة متدرجة حسب قيمة المبيعات التجريبية','sales_value','tiered',0,0,80,true)
  on conflict(company_id,plan_code) do update set plan_name=excluded.plan_name,flat_rate=excluded.flat_rate,fixed_amount=excluded.fixed_amount,is_demo_data=true;

  select id into v_plan from public.erp_commission_plans where company_id=v_company and plan_code='DEMO-COM-TIER';
  insert into public.erp_commission_tiers(plan_id,min_value,max_value,rate,fixed_amount)
  values (v_plan,0,99999.99,0.75,0),(v_plan,100000,249999.99,1.0,0),(v_plan,250000,null,1.5,0)
  on conflict(plan_id,min_value) do update set max_value=excluded.max_value,rate=excluded.rate,fixed_amount=excluded.fixed_amount;

  -- Demo documents are intentionally drafts and are explicitly marked; they must never be
  -- treated as posted accounting, stock movements, or genuine sales.
  if v_customer is not null and v_warehouse is not null then
    insert into public.erp_sales_documents(company_id,branch_id,warehouse_id,customer_id,sales_rep_id,document_number,document_date,due_date,document_type,status,subtotal,grand_total,paid_total,delivery_address,notes,is_demo_data)
    values(v_company,v_branch,v_warehouse,v_customer,v_rep,'DEMO-SI-0001',current_date-2,current_date+7,'invoice','draft',1728,1728,500,'عنوان تجريبي - مدينة نصر','فاتورة تجريبية غير مرحلة؛ لا تمثل عملية حقيقية',true)
    on conflict(company_id,document_number) do update set status='draft',is_demo_data=true,notes=excluded.notes;
    select id into v_doc from public.erp_sales_documents where company_id=v_company and document_number='DEMO-SI-0001';
    select id into v_item1 from public.erp_items where company_id=v_company and item_code='DEMO-OIL-001';
    select id into v_item2 from public.erp_items where company_id=v_company and item_code='DEMO-DRY-001';
    if v_doc is not null and v_item1 is not null then
      insert into public.erp_sales_lines(document_id,item_id,quantity,unit_price,line_total)
      select v_doc,v_item1,24,54,1296
      where not exists(select 1 from public.erp_sales_lines where document_id=v_doc and item_id=v_item1);
    end if;
    if v_doc is not null and v_item2 is not null then
      insert into public.erp_sales_lines(document_id,item_id,quantity,unit_price,line_total)
      select v_doc,v_item2,13.5,32,432
      where not exists(select 1 from public.erp_sales_lines where document_id=v_doc and item_id=v_item2);
    end if;
  end if;
end $$;

comment on table public.erp_geo_areas is 'Hierarchical geographic directory; verify official boundaries and names before production use.';
comment on table public.erp_sales_representatives is 'Sales representatives and their assigned routes; demo names are fictional.';
comment on table public.erp_customer_monthly_goals is 'Customer monthly sales/collection goals; demo targets are fictional.';
comment on table public.erp_commission_plans is 'Percentage, fixed-per-invoice, or tiered commission plan definitions.';
comment on table public.erp_commission_runs is 'Commission calculation records with review and approval lifecycle.';
