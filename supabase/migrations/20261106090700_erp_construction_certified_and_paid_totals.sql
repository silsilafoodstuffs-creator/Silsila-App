alter table public.erp_construction_projects
 add column if not exists certified_amount numeric(18,3) not null default 0 check(certified_amount>=0),
 add column if not exists paid_amount numeric(18,3) not null default 0 check(paid_amount>=0),
 add column if not exists remaining_contract_amount numeric(18,3) generated always as (greatest(contract_value-certified_amount,0)) stored,
 add column if not exists project_margin numeric(18,3) generated always as (contract_value-actual_cost) stored;