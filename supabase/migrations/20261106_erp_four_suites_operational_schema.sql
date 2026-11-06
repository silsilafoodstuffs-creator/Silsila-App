-- Four-suite operational schema for Silsila ERP.
-- Applied to production Supabase as erp_four_suites_operational_schema_20261106.
-- No sample or business data is inserted.
create table if not exists public.erp_asset_categories (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 category_code text not null, name text not null, depreciation_method text not null default 'straight_line' check(depreciation_method in ('straight_line','declining_balance','units_of_production','none')),
 useful_life_months integer not null default 0 check(useful_life_months>=0), residual_percent numeric(8,4) not null default 0 check(residual_percent between 0 and 100),
 asset_account_id uuid references public.erp_accounts(id), accumulated_account_id uuid references public.erp_accounts(id), expense_account_id uuid references public.erp_accounts(id),
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(company_id,category_code), unique(id,company_id));
create table if not exists public.erp_fixed_assets (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, category_id uuid,
 asset_code text not null, name text not null, description text, serial_number text, acquisition_date date not null, in_service_date date,
 acquisition_cost numeric(18,3) not null check(acquisition_cost>=0), residual_value numeric(18,3) not null default 0 check(residual_value>=0),
 useful_life_months integer not null check(useful_life_months>0), depreciation_method text not null default 'straight_line' check(depreciation_method in ('straight_line','declining_balance','units_of_production','none')),
 accumulated_depreciation numeric(18,3) not null default 0 check(accumulated_depreciation>=0),
 net_book_value numeric(18,3) generated always as (greatest(acquisition_cost-accumulated_depreciation,0)) stored,
 location text, custodian text, supplier_name text, purchase_reference text, status text not null default 'draft' check(status in ('draft','active','under_maintenance','disposed','written_off')),
 asset_account_id uuid references public.erp_accounts(id), accumulated_account_id uuid references public.erp_accounts(id), expense_account_id uuid references public.erp_accounts(id),
 created_by uuid default auth.uid(), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,asset_code), unique(id,company_id), foreign key(category_id,company_id) references public.erp_asset_categories(id,company_id));
create table if not exists public.erp_asset_depreciation_runs (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, run_code text not null,
 period_start date not null, period_end date not null, status text not null default 'draft' check(status in ('draft','calculated','posted','cancelled')),
 total_amount numeric(18,3) not null default 0 check(total_amount>=0), journal_entry_id uuid references public.erp_journal_entries(id),
 created_by uuid default auth.uid(), posted_by uuid, posted_at timestamptz, created_at timestamptz not null default now(),
 check(period_end>=period_start), unique(company_id,run_code), unique(id,company_id));
create table if not exists public.erp_asset_depreciation_lines (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, run_id uuid not null, asset_id uuid not null,
 period_start date not null, period_end date not null, amount numeric(18,3) not null check(amount>=0),
 opening_book_value numeric(18,3) not null check(opening_book_value>=0), closing_book_value numeric(18,3) not null check(closing_book_value>=0),
 created_at timestamptz not null default now(), unique(asset_id,period_start,period_end),
 foreign key(run_id,company_id) references public.erp_asset_depreciation_runs(id,company_id) on delete cascade,
 foreign key(asset_id,company_id) references public.erp_fixed_assets(id,company_id));
create table if not exists public.erp_asset_movements (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, asset_id uuid not null,
 movement_type text not null check(movement_type in ('transfer','custody_out','custody_in','maintenance_start','maintenance_end','inventory_check')),
 movement_date date not null, from_location text, to_location text, from_custodian text, to_custodian text, condition_note text, reference text,
 status text not null default 'draft' check(status in ('draft','approved','cancelled')), created_by uuid default auth.uid(), approved_by uuid, approved_at timestamptz, created_at timestamptz not null default now(),
 foreign key(asset_id,company_id) references public.erp_fixed_assets(id,company_id));
create table if not exists public.erp_manufacturing_boms (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, bom_code text not null,
 product_id uuid references public.erp_items(id), product_name text not null, output_quantity numeric(18,4) not null check(output_quantity>0), output_unit text not null,
 version integer not null default 1 check(version>0), scrap_percent numeric(8,4) not null default 0 check(scrap_percent between 0 and 100),
 status text not null default 'draft' check(status in ('draft','active','obsolete')), effective_from date, effective_to date, notes text, created_by uuid default auth.uid(),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(company_id,bom_code,version), unique(id,company_id),
 check(effective_to is null or effective_from is null or effective_to>=effective_from));
create table if not exists public.erp_manufacturing_bom_lines (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, bom_id uuid not null,
 line_no integer not null, item_id uuid references public.erp_items(id), item_name text not null, quantity numeric(18,4) not null check(quantity>0), unit text not null,
 scrap_percent numeric(8,4) not null default 0 check(scrap_percent between 0 and 100), is_byproduct boolean not null default false, notes text, unique(bom_id,line_no),
 foreign key(bom_id,company_id) references public.erp_manufacturing_boms(id,company_id) on delete cascade);
create table if not exists public.erp_manufacturing_work_centers (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, center_code text not null, name text not null,
 center_type text not null default 'production_line', capacity_per_hour numeric(18,4) not null default 0 check(capacity_per_hour>=0),
 hourly_cost numeric(18,3) not null default 0 check(hourly_cost>=0), setup_minutes integer not null default 0 check(setup_minutes>=0),
 location text, supervisor text, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,center_code), unique(id,company_id));
create table if not exists public.erp_production_orders (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, order_code text not null,
 bom_id uuid, product_id uuid references public.erp_items(id), product_name text not null, planned_quantity numeric(18,4) not null check(planned_quantity>0),
 produced_quantity numeric(18,4) not null default 0 check(produced_quantity>=0), scrap_quantity numeric(18,4) not null default 0 check(scrap_quantity>=0),
 planned_start date, planned_end date, actual_start timestamptz, actual_end timestamptz, work_center_id uuid, warehouse_id uuid references public.erp_warehouses(id),
 status text not null default 'draft' check(status in ('draft','confirmed','in_progress','quality_check','done','cancelled')),
 estimated_cost numeric(18,3) not null default 0 check(estimated_cost>=0), actual_cost numeric(18,3) not null default 0 check(actual_cost>=0),
 lot_number text, notes text, created_by uuid default auth.uid(), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,order_code), unique(id,company_id), foreign key(bom_id,company_id) references public.erp_manufacturing_boms(id,company_id),
 foreign key(work_center_id,company_id) references public.erp_manufacturing_work_centers(id,company_id));
create table if not exists public.erp_production_material_movements (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, production_order_id uuid not null,
 item_id uuid references public.erp_items(id), item_name text not null, warehouse_id uuid references public.erp_warehouses(id),
 movement_type text not null check(movement_type in ('issue','return')), quantity numeric(18,4) not null check(quantity>0), unit text not null,
 unit_cost numeric(18,3) not null default 0 check(unit_cost>=0), movement_date date not null, inventory_movement_id uuid, notes text,
 created_by uuid default auth.uid(), created_at timestamptz not null default now(),
 foreign key(production_order_id,company_id) references public.erp_production_orders(id,company_id));
create table if not exists public.erp_production_quality_checks (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, production_order_id uuid not null,
 inspection_stage text not null, parameter_name text not null, measured_value numeric(18,4), minimum_value numeric(18,4), maximum_value numeric(18,4),
 result text not null check(result in ('pass','conditional','fail')), inspected_quantity numeric(18,4) not null default 0 check(inspected_quantity>=0),
 rejected_quantity numeric(18,4) not null default 0 check(rejected_quantity>=0), inspector text, inspected_at timestamptz not null default now(), notes text,
 foreign key(production_order_id,company_id) references public.erp_production_orders(id,company_id));
create table if not exists public.erp_construction_projects (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, project_code text not null, name text not null,
 customer_id uuid references public.erp_parties(id), site_address text, project_type text, contract_number text, contract_value numeric(18,3) not null default 0 check(contract_value>=0),
 planned_start date, planned_end date, actual_start date, actual_end date, status text not null default 'draft' check(status in ('draft','tender','awarded','in_progress','suspended','completed','closed','cancelled')),
 project_manager text, retention_percent numeric(8,4) not null default 0 check(retention_percent between 0 and 100), notes text, created_by uuid default auth.uid(),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(company_id,project_code), unique(id,company_id),
 check(planned_end is null or planned_start is null or planned_end>=planned_start));
create table if not exists public.erp_construction_boq_lines (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, project_id uuid not null,
 item_code text, description text not null, unit text not null, planned_quantity numeric(18,4) not null check(planned_quantity>=0),
 unit_rate numeric(18,3) not null check(unit_rate>=0), executed_quantity numeric(18,4) not null default 0 check(executed_quantity>=0),
 approved_quantity numeric(18,4) not null default 0 check(approved_quantity>=0), line_order integer not null default 0, notes text,
 unique(project_id,line_order), unique(id,company_id), foreign key(project_id,company_id) references public.erp_construction_projects(id,company_id) on delete cascade);
create table if not exists public.erp_construction_costs (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, project_id uuid not null, boq_line_id uuid,
 cost_date date not null, cost_type text not null check(cost_type in ('material','labor','equipment','subcontract','overhead','other')), description text not null,
 quantity numeric(18,4) not null default 1 check(quantity>=0), unit_cost numeric(18,3) not null default 0 check(unit_cost>=0),
 amount numeric(18,3) not null check(amount>=0), supplier_name text, document_reference text, status text not null default 'draft' check(status in ('draft','approved','posted','cancelled')),
 created_by uuid default auth.uid(), created_at timestamptz not null default now(), foreign key(project_id,company_id) references public.erp_construction_projects(id,company_id) on delete cascade,
 foreign key(boq_line_id,company_id) references public.erp_construction_boq_lines(id,company_id));
create table if not exists public.erp_construction_payment_certificates (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, project_id uuid not null, certificate_number text not null,
 period_start date, period_end date, gross_amount numeric(18,3) not null default 0 check(gross_amount>=0),
 retention_amount numeric(18,3) not null default 0 check(retention_amount>=0), advance_recovery numeric(18,3) not null default 0 check(advance_recovery>=0),
 deductions numeric(18,3) not null default 0 check(deductions>=0), net_amount numeric(18,3) generated always as (gross_amount-retention_amount-advance_recovery-deductions) stored,
 status text not null default 'draft' check(status in ('draft','submitted','approved','rejected','paid')), journal_entry_id uuid references public.erp_journal_entries(id),
 submitted_at timestamptz, approved_at timestamptz, paid_at timestamptz, notes text, created_by uuid default auth.uid(), created_at timestamptz not null default now(),
 unique(company_id,certificate_number), unique(id,company_id), foreign key(project_id,company_id) references public.erp_construction_projects(id,company_id) on delete cascade,
 check(period_end is null or period_start is null or period_end>=period_start), check(gross_amount>=retention_amount+advance_recovery+deductions));
create table if not exists public.erp_construction_certificate_lines (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, certificate_id uuid not null, boq_line_id uuid not null,
 current_quantity numeric(18,4) not null check(current_quantity>=0), cumulative_quantity numeric(18,4) not null check(cumulative_quantity>=current_quantity),
 unit_rate numeric(18,3) not null check(unit_rate>=0), amount numeric(18,3) not null check(amount>=0),
 foreign key(certificate_id,company_id) references public.erp_construction_payment_certificates(id,company_id) on delete cascade,
 foreign key(boq_line_id,company_id) references public.erp_construction_boq_lines(id,company_id));
create table if not exists public.erp_crm_leads (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, lead_code text not null, title text not null,
 party_id uuid references public.erp_parties(id), contact_name text, phone text, email text, source text, owner_user_id uuid,
 stage text not null default 'new' check(stage in ('new','qualified','proposal','negotiation','won','lost')),
 probability numeric(5,2) not null default 0 check(probability between 0 and 100), expected_revenue numeric(18,3) not null default 0 check(expected_revenue>=0),
 expected_close_date date, next_activity text, next_activity_at timestamptz, lost_reason text, status text not null default 'open' check(status in ('open','won','lost','archived')),
 created_by uuid default auth.uid(), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,lead_code), unique(id,company_id));
create table if not exists public.erp_service_sla_policies (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, policy_code text not null, name text not null,
 priority text not null check(priority in ('low','normal','high','urgent')), first_response_minutes integer not null check(first_response_minutes>0),
 resolution_minutes integer not null check(resolution_minutes>0), escalation_minutes integer check(escalation_minutes is null or escalation_minutes>0),
 business_hours_only boolean not null default true, is_active boolean not null default true, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), unique(company_id,policy_code), unique(id,company_id));
create table if not exists public.erp_service_tickets (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, ticket_code text not null, subject text not null,
 description text, party_id uuid references public.erp_parties(id), lead_id uuid, channel text not null default 'other', category text not null default 'general',
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 status text not null default 'open' check(status in ('open','assigned','in_progress','waiting_customer','resolved','closed','cancelled')),
 team_name text, assigned_to uuid, sla_policy_id uuid, first_response_due_at timestamptz, resolution_due_at timestamptz,
 first_responded_at timestamptz, resolved_at timestamptz, closed_at timestamptz, satisfaction_score numeric(3,2) check(satisfaction_score between 0 and 5),
 resolution text, created_by uuid default auth.uid(), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,ticket_code), unique(id,company_id), foreign key(lead_id,company_id) references public.erp_crm_leads(id,company_id),
 foreign key(sla_policy_id,company_id) references public.erp_service_sla_policies(id,company_id));
create table if not exists public.erp_service_ticket_events (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, ticket_id uuid not null,
 event_type text not null, from_status text, to_status text, note text, performed_by uuid default auth.uid(), performed_at timestamptz not null default now(),
 foreign key(ticket_id,company_id) references public.erp_service_tickets(id,company_id) on delete cascade);
create table if not exists public.erp_service_visits (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, visit_code text not null,
 ticket_id uuid, party_id uuid references public.erp_parties(id), scheduled_at timestamptz not null, address text, assigned_to uuid,
 visit_type text not null default 'service', status text not null default 'planned' check(status in ('planned','confirmed','in_progress','completed','cancelled','missed')),
 started_at timestamptz, completed_at timestamptz, labor_minutes integer not null default 0 check(labor_minutes>=0), materials jsonb not null default '[]'::jsonb,
 outcome text, customer_signature_reference text, created_by uuid default auth.uid(), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,visit_code), foreign key(ticket_id,company_id) references public.erp_service_tickets(id,company_id));
create table if not exists public.erp_crm_activities (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade, activity_code text not null,
 activity_type text not null check(activity_type in ('call','email','whatsapp','meeting','visit','task','reminder')), subject text not null,
 lead_id uuid, ticket_id uuid, party_id uuid references public.erp_parties(id), assigned_to uuid, scheduled_at timestamptz, completed_at timestamptz,
 outcome text, next_step text, status text not null default 'planned' check(status in ('planned','done','cancelled')), created_by uuid default auth.uid(),
 created_at timestamptz not null default now(), unique(company_id,activity_code),
 foreign key(lead_id,company_id) references public.erp_crm_leads(id,company_id), foreign key(ticket_id,company_id) references public.erp_service_tickets(id,company_id));

create index if not exists erp_fixed_assets_company_status_idx on public.erp_fixed_assets(company_id,status);
create index if not exists erp_asset_depreciation_period_idx on public.erp_asset_depreciation_lines(company_id,period_start,asset_id);
create index if not exists erp_asset_movements_asset_date_idx on public.erp_asset_movements(company_id,asset_id,movement_date desc);
create index if not exists erp_bom_lines_bom_idx on public.erp_manufacturing_bom_lines(company_id,bom_id,line_no);
create index if not exists erp_production_orders_status_idx on public.erp_production_orders(company_id,status,planned_start);
create index if not exists erp_production_material_order_idx on public.erp_production_material_movements(company_id,production_order_id,movement_date);
create index if not exists erp_construction_projects_status_idx on public.erp_construction_projects(company_id,status);
create index if not exists erp_construction_boq_project_idx on public.erp_construction_boq_lines(company_id,project_id,line_order);
create index if not exists erp_construction_cost_project_idx on public.erp_construction_costs(company_id,project_id,cost_date);
create index if not exists erp_certificates_project_idx on public.erp_construction_payment_certificates(company_id,project_id,status);
create index if not exists erp_crm_leads_stage_idx on public.erp_crm_leads(company_id,stage,expected_close_date);
create index if not exists erp_service_tickets_status_idx on public.erp_service_tickets(company_id,status,priority,resolution_due_at);
create index if not exists erp_service_events_ticket_idx on public.erp_service_ticket_events(company_id,ticket_id,performed_at);
create index if not exists erp_service_visits_schedule_idx on public.erp_service_visits(company_id,scheduled_at,status);
create index if not exists erp_crm_activities_schedule_idx on public.erp_crm_activities(company_id,scheduled_at,status);

do $$
declare t text;
begin
 foreach t in array array['erp_asset_categories','erp_fixed_assets','erp_asset_depreciation_runs','erp_asset_depreciation_lines','erp_asset_movements','erp_manufacturing_boms','erp_manufacturing_bom_lines','erp_manufacturing_work_centers','erp_production_orders','erp_production_material_movements','erp_production_quality_checks','erp_construction_projects','erp_construction_boq_lines','erp_construction_costs','erp_construction_payment_certificates','erp_construction_certificate_lines','erp_crm_leads','erp_service_sla_policies','erp_service_tickets','erp_service_ticket_events','erp_service_visits','erp_crm_activities'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('grant select,insert,update,delete on public.%I to authenticated',t);
  execute format('create policy %I on public.%I for select to authenticated using (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'',''manager'']) or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = (select auth.uid())))',t||'_select',t,t);
  execute format('create policy %I on public.%I for insert to authenticated with check (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'',''manager'']) or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = (select auth.uid())))',t||'_insert',t,t);
  execute format('create policy %I on public.%I for update to authenticated using (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'',''manager'']) or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = (select auth.uid()))) with check (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'',''manager'']) or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = (select auth.uid())))',t||'_update',t,t,t);
  execute format('create policy %I on public.%I for delete to authenticated using (public.erp_user_has_company_role(company_id, ARRAY[''owner'',''admin'']))',t||'_delete',t);
 end loop;
end $$;
