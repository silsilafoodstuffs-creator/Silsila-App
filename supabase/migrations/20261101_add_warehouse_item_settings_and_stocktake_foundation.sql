
create table if not exists public.erp_item_warehouse_settings (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 item_id uuid not null references public.erp_items(id) on delete cascade, warehouse_id uuid not null references public.erp_warehouses(id) on delete cascade,
 purchase_unit_id uuid references public.erp_item_units(id) on delete restrict, sale_unit_id uuid references public.erp_item_units(id) on delete restrict,
 transfer_unit_id uuid references public.erp_item_units(id) on delete restrict, stop_purchase boolean not null default false,
 stop_sale boolean not null default false, stop_transfer boolean not null default false, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), unique(item_id,warehouse_id));
create index if not exists erp_item_warehouse_settings_company_warehouse_idx on public.erp_item_warehouse_settings(company_id,warehouse_id);
create table if not exists public.erp_stocktakes (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 branch_id uuid references public.erp_branches(id), warehouse_id uuid not null references public.erp_warehouses(id),
 source text not null default 'manual' check(source in ('manual','stocktake')), status text not null default 'draft' check(status in ('draft','posted')),
 count_mode text not null default 'detailed' check(count_mode in ('default','detailed')), valuation_basis text not null default 'sale' check(valuation_basis in ('sale','purchase')),
 notes text, created_by uuid, created_at timestamptz not null default now(), posted_at timestamptz);
create table if not exists public.erp_stocktake_lines (
 id uuid primary key default gen_random_uuid(), stocktake_id uuid not null references public.erp_stocktakes(id) on delete cascade,
 company_id uuid not null references public.erp_companies(id) on delete cascade, warehouse_id uuid not null references public.erp_warehouses(id),
 item_id uuid not null references public.erp_items(id), available_snapshot numeric(18,6) not null default 0,
 reserved_snapshot numeric(18,6) not null default 0, physical_snapshot numeric(18,6) not null default 0,
 counted_quantity numeric(18,6) not null default 0, variance_quantity numeric(18,6) not null default 0,
 unit_id uuid references public.erp_item_units(id), conversion_factor numeric(18,6) not null default 1 check(conversion_factor>0),
 valuation_price numeric(18,6) not null default 0 check(valuation_price>=0), valuation_value numeric(18,2) not null default 0,
 created_at timestamptz not null default now(), unique(stocktake_id,item_id));
create table if not exists public.erp_stock_adjustment_lines (
 id uuid primary key default gen_random_uuid(), stocktake_id uuid not null references public.erp_stocktakes(id) on delete cascade,
 company_id uuid not null references public.erp_companies(id) on delete cascade, item_id uuid not null references public.erp_items(id),
 increase_quantity numeric(18,6) not null default 0 check(increase_quantity>=0), shortage_quantity numeric(18,6) not null default 0 check(shortage_quantity>=0),
 unit_cost numeric(18,6) not null default 0 check(unit_cost>=0), valuation_value numeric(18,2) not null default 0,
 unique(stocktake_id,item_id), check(not (increase_quantity>0 and shortage_quantity>0)));
alter table public.erp_item_warehouse_settings enable row level security;
alter table public.erp_stocktakes enable row level security;
alter table public.erp_stocktake_lines enable row level security;
alter table public.erp_stock_adjustment_lines enable row level security;
drop policy if exists erp_item_warehouse_settings_company_access on public.erp_item_warehouse_settings;
create policy erp_item_warehouse_settings_company_access on public.erp_item_warehouse_settings for all to authenticated using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));
drop policy if exists erp_stocktakes_company_access on public.erp_stocktakes;
create policy erp_stocktakes_company_access on public.erp_stocktakes for all to authenticated using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));
drop policy if exists erp_stocktake_lines_company_access on public.erp_stocktake_lines;
create policy erp_stocktake_lines_company_access on public.erp_stocktake_lines for all to authenticated using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));
drop policy if exists erp_stock_adjustment_lines_company_access on public.erp_stock_adjustment_lines;
create policy erp_stock_adjustment_lines_company_access on public.erp_stock_adjustment_lines for all to authenticated using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));
alter table public.erp_hr_salary_elements add column if not exists is_system_locked boolean not null default false;
insert into public.erp_hr_salary_elements(company_id,element_code,name_ar,name_en,element_type,value_mode,nature,default_value,show_on_payslip,is_active,is_system_locked)
select c.id,'SYSSTOCKSHORTAGE','عجز جرد','Stock Count Shortage','deduction','variable','value',0,true,true,true
from public.erp_companies c
where not exists(select 1 from public.erp_hr_salary_elements e where e.company_id=c.id and e.element_code='SYSSTOCKSHORTAGE');
