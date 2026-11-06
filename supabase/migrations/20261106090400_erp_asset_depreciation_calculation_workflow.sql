create or replace function public.erp_calculate_asset_depreciation(p_company_id uuid,p_run_id uuid)
returns numeric(18,3) language plpgsql security invoker set search_path=public,pg_temp
as $$
declare v_run public.erp_asset_depreciation_runs%rowtype; v_asset public.erp_fixed_assets%rowtype;
 v_opening numeric(18,3); v_amount numeric(18,3); v_total numeric(18,3):=0; v_months integer; v_existing numeric(18,3);
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if not (public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','accountant'])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=p_company_id and p.user_id=(select auth.uid()))) then
  raise exception 'لا تملك صلاحية احتساب إهلاك الشركة';
 end if;
 select * into v_run from public.erp_asset_depreciation_runs r where r.id=p_run_id and r.company_id=p_company_id for update;
 if not found then raise exception 'تشغيل الإهلاك غير موجود'; end if;
 if v_run.status='posted' or v_run.status='cancelled' then raise exception 'لا يمكن إعادة احتساب تشغيل مرحّل أو ملغي'; end if;
 select coalesce(sum(l.amount),0) into v_existing from public.erp_asset_depreciation_lines l where l.company_id=p_company_id and l.run_id=p_run_id;
 if exists(select 1 from public.erp_asset_depreciation_lines l where l.company_id=p_company_id and l.run_id=p_run_id) then return v_existing; end if;
 for v_asset in select * from public.erp_fixed_assets a where a.company_id=p_company_id and a.status='active'
  and coalesce(a.in_service_date,a.acquisition_date)<=v_run.period_end order by a.asset_code for update
 loop
  if v_asset.depreciation_method='units_of_production' then raise exception 'الأصل % يستخدم طريقة وحدات الإنتاج، ويلزم إدخال وحدات الإنتاج للفترة قبل احتسابه',v_asset.asset_code; end if;
  v_opening:=greatest(v_asset.acquisition_cost-v_asset.accumulated_depreciation,0);
  if v_opening<=v_asset.residual_value or v_asset.depreciation_method='none' then v_amount:=0;
  else
   v_months:=greatest(v_asset.useful_life_months,1);
   if v_asset.depreciation_method='declining_balance' then v_amount:=round(v_opening*(2.0/v_months),3);
   else v_amount:=round((v_asset.acquisition_cost-v_asset.residual_value)/v_months,3); end if;
   v_amount:=least(greatest(v_amount,0),greatest(v_opening-v_asset.residual_value,0));
  end if;
  if exists(select 1 from public.erp_asset_depreciation_lines l where l.company_id=p_company_id and l.asset_id=v_asset.id and l.period_start=v_run.period_start and l.period_end=v_run.period_end) then
   raise exception 'تم احتساب إهلاك الأصل % لهذه الفترة في تشغيل آخر',v_asset.asset_code;
  end if;
  insert into public.erp_asset_depreciation_lines(company_id,run_id,asset_id,period_start,period_end,amount,opening_book_value,closing_book_value)
   values(p_company_id,p_run_id,v_asset.id,v_run.period_start,v_run.period_end,v_amount,v_opening,greatest(v_opening-v_amount,0));
  update public.erp_fixed_assets set accumulated_depreciation=accumulated_depreciation+v_amount,updated_at=now() where id=v_asset.id and company_id=p_company_id;
  v_total:=v_total+v_amount;
 end loop;
 update public.erp_asset_depreciation_runs set total_amount=v_total,status='calculated' where id=p_run_id and company_id=p_company_id;
 return v_total;
end;
$$;
revoke all on function public.erp_calculate_asset_depreciation(uuid,uuid) from public,anon;
grant execute on function public.erp_calculate_asset_depreciation(uuid,uuid) to authenticated;
