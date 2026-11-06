alter table public.erp_asset_categories add column if not exists useful_life_units numeric(18,4) not null default 0 check(useful_life_units>=0);
alter table public.erp_fixed_assets add column if not exists useful_life_units numeric(18,4) not null default 0 check(useful_life_units>=0);
create table if not exists public.erp_asset_depreciation_inputs (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.erp_companies(id) on delete cascade,
 run_id uuid not null,asset_id uuid not null,units_produced numeric(18,4) not null check(units_produced>0),
 created_by uuid default auth.uid(),created_at timestamptz not null default now(),
 unique(run_id,asset_id),foreign key(run_id,company_id) references public.erp_asset_depreciation_runs(id,company_id) on delete cascade,
 foreign key(asset_id,company_id) references public.erp_fixed_assets(id,company_id)
);
create index if not exists erp_asset_depreciation_inputs_company_idx on public.erp_asset_depreciation_inputs(company_id,run_id);
alter table public.erp_asset_depreciation_inputs enable row level security;
grant select,insert,update,delete on public.erp_asset_depreciation_inputs to authenticated;
create policy erp_asset_depreciation_inputs_select on public.erp_asset_depreciation_inputs for select to authenticated using(public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager','accountant']) or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_asset_depreciation_inputs.company_id and p.user_id=(select auth.uid())));
create policy erp_asset_depreciation_inputs_insert on public.erp_asset_depreciation_inputs for insert to authenticated with check(public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager','accountant']) or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_asset_depreciation_inputs.company_id and p.user_id=(select auth.uid())));
create policy erp_asset_depreciation_inputs_update on public.erp_asset_depreciation_inputs for update to authenticated using(public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager','accountant']) or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_asset_depreciation_inputs.company_id and p.user_id=(select auth.uid()))) with check(public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager','accountant']) or exists(select 1 from public.erp_company_member_profiles p where p.company_id=erp_asset_depreciation_inputs.company_id and p.user_id=(select auth.uid())));
create policy erp_asset_depreciation_inputs_delete on public.erp_asset_depreciation_inputs for delete to authenticated using(public.erp_user_has_company_role(company_id,ARRAY['owner','admin']));

do $$
declare v_definition text;
begin
 v_definition:=pg_get_functiondef('public.erp_calculate_asset_depreciation(uuid,uuid)'::regprocedure);
 v_definition:=replace(v_definition,' v_existing numeric(18,3);',E' v_existing numeric(18,3);\n v_units numeric(18,4);');
 v_definition:=replace(v_definition,
  E'  if v_asset.depreciation_method=''units_of_production'' then\n   raise exception ''الأصل % يستخدم طريقة وحدات الإنتاج، ويلزم إدخال وحدات الإنتاج للفترة قبل احتسابه'',v_asset.asset_code;\n  end if;\n','');
 v_definition:=replace(v_definition,
  E'   if v_asset.depreciation_method=''declining_balance'' then\n    v_amount:=round(v_opening*(2.0/v_months),3);\n   else\n    v_amount:=round((v_asset.acquisition_cost-v_asset.residual_value)/v_months,3);\n   end if;',
  E'   if v_asset.depreciation_method=''units_of_production'' then\n    if v_asset.useful_life_units<=0 then raise exception ''حدد إجمالي وحدات العمر الإنتاجي للأصل %'',v_asset.asset_code; end if;\n    select i.units_produced into v_units from public.erp_asset_depreciation_inputs i where i.company_id=p_company_id and i.run_id=p_run_id and i.asset_id=v_asset.id;\n    if not found then raise exception ''أدخل وحدات الإنتاج للفترة للأصل %'',v_asset.asset_code; end if;\n    v_amount:=round((v_asset.acquisition_cost-v_asset.residual_value)*v_units/v_asset.useful_life_units,3);\n   elsif v_asset.depreciation_method=''declining_balance'' then\n    v_amount:=round(v_opening*(2.0/v_months),3);\n   else\n    v_amount:=round((v_asset.acquisition_cost-v_asset.residual_value)/v_months,3);\n   end if;');
 if v_definition not like '%v_units numeric(18,4)%' or v_definition like '%يلزم إدخال وحدات الإنتاج للفترة قبل احتسابه%' then raise exception 'تعذر تحديث معادلة إهلاك وحدات الإنتاج'; end if;
 execute v_definition;
end $$;
