alter table public.erp_asset_disposals
 add column if not exists cash_account_id uuid references public.erp_accounts(id),
 add column if not exists gain_loss_account_id uuid references public.erp_accounts(id);
alter table public.erp_asset_disposals drop constraint if exists erp_asset_disposals_status_check;
alter table public.erp_asset_disposals add constraint erp_asset_disposals_status_check check(status in ('draft','approved','posted','cancelled'));

create or replace function public.erp_post_asset_disposal(p_company_id uuid,p_disposal_id uuid)
returns uuid language plpgsql security invoker set search_path=public,pg_temp
as $$
declare v_disposal public.erp_asset_disposals%rowtype; v_asset public.erp_fixed_assets%rowtype;
 v_lines jsonb:='[]'::jsonb; v_entry_id uuid; v_book numeric(18,3); v_gain numeric(18,3); v_loss numeric(18,3);
begin
 if auth.uid() is null then raise exception 'يلزم تسجيل الدخول'; end if;
 if not (public.erp_user_has_company_role(p_company_id,array['owner','admin','manager','accountant'])
  or exists(select 1 from public.erp_company_member_profiles p where p.company_id=p_company_id and p.user_id=(select auth.uid()))) then
  raise exception 'لا تملك صلاحية ترحيل استبعاد الأصول';
 end if;
 select * into v_disposal from public.erp_asset_disposals d where d.id=p_disposal_id and d.company_id=p_company_id for update;
 if not found then raise exception 'عملية استبعاد الأصل غير موجودة'; end if;
 if v_disposal.status='posted' and v_disposal.journal_entry_id is not null then return v_disposal.journal_entry_id; end if;
 if v_disposal.status not in ('approved','draft') then raise exception 'حالة الاستبعاد لا تسمح بالترحيل'; end if;
 select * into v_asset from public.erp_fixed_assets a where a.id=v_disposal.asset_id and a.company_id=p_company_id for update;
 if not found then raise exception 'الأصل المرتبط بالاستبعاد غير موجود'; end if;
 if v_asset.status='disposed' then raise exception 'الأصل مستبعد بالفعل'; end if;
 v_book:=greatest(v_asset.acquisition_cost-v_asset.accumulated_depreciation,0);
 if abs(v_disposal.book_value-v_book)>0.01 then raise exception 'القيمة الدفترية المسجلة لا تطابق القيمة الحالية للأصل؛ حدّث عملية الاستبعاد أولاً'; end if;
 v_gain:=greatest(v_disposal.proceeds-v_book,0);v_loss:=greatest(v_book-v_disposal.proceeds,0);
 if v_asset.asset_account_id is null then raise exception 'اربط حساب الأصل قبل الاستبعاد'; end if;
 if v_asset.accumulated_depreciation>0 and v_asset.accumulated_account_id is null then raise exception 'اربط حساب مجمع الإهلاك قبل الاستبعاد'; end if;
 if v_disposal.proceeds>0 and v_disposal.cash_account_id is null then raise exception 'حدد حساب مقابل البيع أو النقدية'; end if;
 if (v_gain>0 or v_loss>0) and v_disposal.gain_loss_account_id is null then raise exception 'حدد حساب أرباح أو خسائر استبعاد الأصول'; end if;
 if v_asset.accumulated_depreciation>0 then
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_asset.accumulated_account_id,'debit',v_asset.accumulated_depreciation,'credit',0,'description','إقفال مجمع إهلاك الأصل '||v_asset.asset_code));
 end if;
 if v_disposal.proceeds>0 then
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_disposal.cash_account_id,'debit',v_disposal.proceeds,'credit',0,'description','متحصلات استبعاد الأصل '||v_asset.asset_code));
 end if;
 v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_asset.asset_account_id,'debit',0,'credit',v_asset.acquisition_cost,'description','إخراج تكلفة الأصل '||v_asset.asset_code));
 if v_gain>0 then
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_disposal.gain_loss_account_id,'debit',0,'credit',v_gain,'description','ربح استبعاد الأصل '||v_asset.asset_code));
 end if;
 if v_loss>0 then
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_id',v_disposal.gain_loss_account_id,'debit',v_loss,'credit',0,'description','خسارة استبعاد الأصل '||v_asset.asset_code));
 end if;
 v_entry_id:=public.erp_save_journal_draft(p_company_id,v_disposal.disposal_date,'قيد استبعاد أصل - '||v_disposal.disposal_code,v_lines,null);
 perform public.erp_post_journal_entry(v_entry_id);
 update public.erp_asset_disposals set status='posted',journal_entry_id=v_entry_id where id=p_disposal_id and company_id=p_company_id;
 update public.erp_fixed_assets set status='disposed',updated_at=now() where id=v_asset.id and company_id=p_company_id;
 return v_entry_id;
end;
$$;
revoke all on function public.erp_post_asset_disposal(uuid,uuid) from public,anon;
grant execute on function public.erp_post_asset_disposal(uuid,uuid) to authenticated;
