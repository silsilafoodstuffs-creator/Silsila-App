create or replace function public.erp_post_asset_depreciation_run(p_company_id uuid,p_run_id uuid)
returns uuid language plpgsql security invoker set search_path=public,pg_temp
as $$
declare v_run public.erp_asset_depreciation_runs%rowtype; v_lines jsonb; v_entry_id uuid;
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if not (public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','accountant'])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=p_company_id and p.user_id=(select auth.uid()))) then
  raise exception 'لا تملك صلاحية ترحيل إهلاك الأصول';
 end if;
 select * into v_run from public.erp_asset_depreciation_runs r where r.id=p_run_id and r.company_id=p_company_id for update;
 if not found then raise exception 'تشغيل الإهلاك غير موجود'; end if;
 if v_run.status='posted' and v_run.journal_entry_id is not null then return v_run.journal_entry_id; end if;
 if v_run.status<>'calculated' then raise exception 'احسب الإهلاك أولاً قبل الترحيل'; end if;
 if not exists(select 1 from public.erp_asset_depreciation_lines l where l.company_id=p_company_id and l.run_id=p_run_id and l.amount>0) then raise exception 'لا توجد أقساط إهلاك موجبة لترحيلها'; end if;
 if exists(select 1 from public.erp_asset_depreciation_lines l join public.erp_fixed_assets a on a.id=l.asset_id and a.company_id=l.company_id
  where l.company_id=p_company_id and l.run_id=p_run_id and l.amount>0 and (a.expense_account_id is null or a.accumulated_account_id is null)) then
  raise exception 'اربط حساب مصروف الإهلاك وحساب مجمع الإهلاك بكل أصل قبل الترحيل';
 end if;
 select jsonb_agg(x.line) into v_lines from (
  select jsonb_build_object('account_id',a.expense_account_id,'debit',sum(l.amount),'credit',0,'description','مصروف إهلاك الأصل '||a.asset_code) as line
  from public.erp_asset_depreciation_lines l join public.erp_fixed_assets a on a.id=l.asset_id and a.company_id=l.company_id
  where l.company_id=p_company_id and l.run_id=p_run_id and l.amount>0 group by a.expense_account_id,a.asset_code
  union all
  select jsonb_build_object('account_id',a.accumulated_account_id,'debit',0,'credit',sum(l.amount),'description','مجمع إهلاك الأصل '||a.asset_code) as line
  from public.erp_asset_depreciation_lines l join public.erp_fixed_assets a on a.id=l.asset_id and a.company_id=l.company_id
  where l.company_id=p_company_id and l.run_id=p_run_id and l.amount>0 group by a.accumulated_account_id,a.asset_code
 ) x;
 v_entry_id:=public.erp_save_journal_draft(p_company_id,v_run.period_end,'قيد إهلاك الأصول - '||v_run.run_code,v_lines,null);
 perform public.erp_post_journal_entry(v_entry_id);
 update public.erp_asset_depreciation_runs set journal_entry_id=v_entry_id,status='posted',posted_by=auth.uid(),posted_at=now()
 where id=p_run_id and company_id=p_company_id;
 return v_entry_id;
end;
$$;
revoke all on function public.erp_post_asset_depreciation_run(uuid,uuid) from public,anon;
grant execute on function public.erp_post_asset_depreciation_run(uuid,uuid) to authenticated;
