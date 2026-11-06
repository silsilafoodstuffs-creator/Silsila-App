create table if not exists public.erp_production_variances (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.erp_companies(id) on delete cascade,
 variance_code text not null, production_order_id uuid not null, item_id uuid references public.erp_items(id),
 item_name text not null, variance_type text not null check(variance_type in ('scrap','byproduct','disassembly','rework')),
 quantity numeric(18,4) not null check(quantity>0), unit text not null, unit_cost numeric(18,3) not null default 0 check(unit_cost>=0),
 amount numeric(18,3) generated always as (quantity*unit_cost) stored, reason text, movement_date date not null,
 created_by uuid default auth.uid(), created_at timestamptz not null default now(), unique(company_id,variance_code),
 foreign key(production_order_id,company_id) references public.erp_production_orders(id,company_id)
);
create index if not exists erp_production_variances_order_idx on public.erp_production_variances(company_id,production_order_id,movement_date desc);
alter table public.erp_production_variances enable row level security;
grant select,insert,update,delete on public.erp_production_variances to authenticated;
create policy erp_production_variances_select on public.erp_production_variances for select to authenticated using (public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager']) or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_production_variances.company_id and p.user_id=(select auth.uid())));
create policy erp_production_variances_insert on public.erp_production_variances for insert to authenticated with check (public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager']) or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_production_variances.company_id and p.user_id=(select auth.uid())));
create policy erp_production_variances_update on public.erp_production_variances for update to authenticated using (public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager']) or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_production_variances.company_id and p.user_id=(select auth.uid()))) with check (public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager']) or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_production_variances.company_id and p.user_id=(select auth.uid())));
create policy erp_production_variances_delete on public.erp_production_variances for delete to authenticated using (public.erp_user_has_company_role(company_id,ARRAY['owner','admin']));
