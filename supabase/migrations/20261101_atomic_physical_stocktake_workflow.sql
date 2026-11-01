-- Atomic physical stocktake workflow: snapshot, count entry, valuation and posting.
create table if not exists public.erp_stocktake_expense_items (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 item_code text not null,
 name_ar text not null,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 unique(company_id,item_code)
);
alter table public.erp_stocktakes
 add column if not exists settlement_target_type text,
 add column if not exists settlement_target_id uuid;
alter table public.erp_stocktakes
 drop constraint if exists erp_stocktakes_settlement_target_type_check;
alter table public.erp_stocktakes
 add constraint erp_stocktakes_settlement_target_type_check
 check(settlement_target_type is null or settlement_target_type in ('employee','expense'));
create table if not exists public.erp_stocktake_settlements (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 stocktake_id uuid not null references public.erp_stocktakes(id) on delete restrict,
 target_type text not null check(target_type in ('employee','expense')),
 target_id uuid not null,
 amount numeric(18,2) not null check(amount>=0),
 created_at timestamptz not null default now(),
 unique(stocktake_id)
);
alter table public.erp_stocktake_expense_items enable row level security;
alter table public.erp_stocktake_settlements enable row level security;
drop policy if exists erp_stocktake_expense_items_company_access on public.erp_stocktake_expense_items;
create policy erp_stocktake_expense_items_company_access on public.erp_stocktake_expense_items
 for all to authenticated using(public.erp_user_can_access_company(company_id))
 with check(public.erp_user_can_access_company(company_id));
drop policy if exists erp_stocktake_settlements_company_access on public.erp_stocktake_settlements;
create policy erp_stocktake_settlements_company_access on public.erp_stocktake_settlements
 for all to authenticated using(public.erp_user_can_access_company(company_id))
 with check(public.erp_user_can_access_company(company_id));

create or replace function public.erp_create_physical_stocktake(
 p_company_id uuid,p_warehouse_id uuid,p_count_mode text default 'detailed',
 p_valuation_basis text default 'sale',p_notes text default null
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_branch uuid; v_basis text; v_mode text;
begin
 if auth.uid() is null or not public.erp_user_can_access_company(p_company_id) then
   raise exception 'غير مصرح بإنشاء جرد لهذه الشركة' using errcode='42501';
 end if;
 if p_count_mode not in ('default','detailed') then raise exception 'وضع الجرد غير صحيح'; end if;
 select branch_id into v_branch from public.erp_warehouses
 where id=p_warehouse_id and company_id=p_company_id and is_active=true;
 if not found then raise exception 'المخزن غير موجود أو غير نشط'; end if;
 select coalesce((select policy_value from public.erp_program_policies
   where company_id=p_company_id and policy_key='inventory.stocktake.valuation_basis'
   and is_enabled=true order by updated_at desc limit 1),'sale') into v_basis;
 if p_valuation_basis in ('sale','purchase') then v_basis:=p_valuation_basis; end if;
 v_mode:=p_count_mode;
 insert into public.erp_stocktakes(company_id,branch_id,warehouse_id,source,status,count_mode,valuation_basis,notes,created_by)
 values(p_company_id,v_branch,p_warehouse_id,'stocktake','draft',v_mode,v_basis,p_notes,auth.uid())
 returning id into v_id;
 insert into public.erp_stocktake_lines(
   stocktake_id,company_id,warehouse_id,item_id,available_snapshot,reserved_snapshot,
   physical_snapshot,counted_quantity,variance_quantity,unit_id,conversion_factor,
   valuation_price,valuation_value)
 select v_id,i.company_id,p_warehouse_id,i.id,
   coalesce(b.quantity_on_hand,0)-coalesce(r.reserved,0),
   coalesce(r.reserved,0),coalesce(b.quantity_on_hand,0),coalesce(b.quantity_on_hand,0),0,
   coalesce(s.sale_unit_id,s.purchase_unit_id,u.id),
   coalesce((select iu.conversion_factor from public.erp_item_units iu
      where iu.id=coalesce(s.sale_unit_id,s.purchase_unit_id,u.id)),1),
   case when v_basis='purchase' then i.purchase_price else i.sale_price end,0
 from public.erp_items i
 left join public.erp_stock_balances b on b.company_id=i.company_id and b.warehouse_id=p_warehouse_id and b.item_id=i.id
 left join lateral (select sum(sr.quantity_base) reserved from public.erp_stock_reservations sr
   where sr.company_id=i.company_id and sr.warehouse_id=p_warehouse_id and sr.item_id=i.id and sr.status='active') r on true
 left join public.erp_item_warehouse_settings s on s.company_id=i.company_id and s.item_id=i.id and s.warehouse_id=p_warehouse_id
 left join lateral (select iu.id from public.erp_item_units iu where iu.company_id=i.company_id and iu.item_id=i.id
   and iu.is_active and iu.is_selectable order by iu.conversion_factor desc limit 1) u on true
 where i.company_id=p_company_id and i.is_active=true;
 return v_id;
end $$;

create or replace function public.erp_post_physical_stocktake(
 p_stocktake_id uuid,p_target_type text default null,p_target_id uuid default null
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_doc public.erp_stocktakes%rowtype; v_total numeric(18,2); v_shortage numeric(18,2);
begin
 select * into v_doc from public.erp_stocktakes where id=p_stocktake_id for update;
 if not found then raise exception 'محضر الجرد غير موجود'; end if;
 if auth.uid() is null or not public.erp_user_can_access_company(v_doc.company_id) then
   raise exception 'غير مصرح بترحيل محضر الجرد' using errcode='42501';
 end if;
 if v_doc.status<>'draft' or v_doc.source<>'stocktake' then raise exception 'المحضر ليس مسودة جرد فعلية قابلة للترحيل'; end if;
 if exists(select 1 from public.erp_stocktake_lines where stocktake_id=p_stocktake_id and counted_quantity<0) then
   raise exception 'لا يمكن ترحيل كمية جرد سالبة';
 end if;
 update public.erp_stocktake_lines
 set variance_quantity=counted_quantity-physical_snapshot,
     valuation_value=round(abs(counted_quantity-physical_snapshot)*valuation_price,2)
 where stocktake_id=p_stocktake_id;
 select coalesce(sum(valuation_value),0),
        coalesce(sum(case when variance_quantity<0 then valuation_value else 0 end),0)
 into v_total,v_shortage
 from public.erp_stocktake_lines where stocktake_id=p_stocktake_id;
 if v_shortage>0 then
   if p_target_type not in ('employee','expense') or p_target_id is null then
     raise exception 'يجب تحديد الموظف أو بند الصرف لتوجيه قيمة العجز';
   end if;
   if p_target_type='employee' and not exists(select 1 from public.erp_employees
       where id=p_target_id and company_id=v_doc.company_id and is_active=true) then
     raise exception 'الموظف المحدد غير موجود أو غير نشط';
   end if;
   if p_target_type='expense' and not exists(select 1 from public.erp_stocktake_expense_items
       where id=p_target_id and company_id=v_doc.company_id and is_active=true) then
     raise exception 'بند الصرف المحدد غير موجود أو غير نشط';
   end if;
 end if;
 insert into public.erp_stock_adjustment_lines(stocktake_id,company_id,item_id,increase_quantity,shortage_quantity,unit_cost,valuation_value)
 select p_stocktake_id,v_doc.company_id,l.item_id,greatest(l.variance_quantity,0),greatest(-l.variance_quantity,0),
        coalesce(b.average_unit_cost,case when v_doc.valuation_basis='purchase' then i.purchase_price else i.sale_price end,0),
        l.valuation_value
 from public.erp_stocktake_lines l
 join public.erp_items i on i.id=l.item_id and i.company_id=l.company_id
 left join public.erp_stock_balances b on b.company_id=l.company_id and b.warehouse_id=l.warehouse_id and b.item_id=l.item_id
 where l.stocktake_id=p_stocktake_id and l.variance_quantity<>0
 on conflict(stocktake_id,item_id) do update set
  increase_quantity=excluded.increase_quantity,shortage_quantity=excluded.shortage_quantity,
  unit_cost=excluded.unit_cost,valuation_value=excluded.valuation_value;
 insert into public.erp_inventory_movements(company_id,branch_id,warehouse_id,item_id,movement_date,movement_type,quantity_in,quantity_out,unit_cost,reference_type,reference_id,notes,created_by)
 select v_doc.company_id,v_doc.branch_id,v_doc.warehouse_id,l.item_id,now(),
        case when l.variance_quantity>0 then 'stocktake_increase' else 'stocktake_shortage' end,
        greatest(l.variance_quantity,0),greatest(-l.variance_quantity,0),
        coalesce(b.average_unit_cost,case when v_doc.valuation_basis='purchase' then i.purchase_price else i.sale_price end,0),
        'stocktake',p_stocktake_id,'ترحيل جرد فعلي',auth.uid()
 from public.erp_stocktake_lines l
 join public.erp_items i on i.id=l.item_id and i.company_id=l.company_id
 left join public.erp_stock_balances b on b.company_id=l.company_id and b.warehouse_id=l.warehouse_id and b.item_id=l.item_id
 where l.stocktake_id=p_stocktake_id and l.variance_quantity<>0;
 if v_shortage>0 then
   insert into public.erp_stocktake_settlements(company_id,stocktake_id,target_type,target_id,amount)
   values(v_doc.company_id,p_stocktake_id,p_target_type,p_target_id,v_shortage);
   update public.erp_stocktakes set settlement_target_type=p_target_type,settlement_target_id=p_target_id where id=p_stocktake_id;
 end if;
 update public.erp_stocktakes set status='posted',posted_at=now() where id=p_stocktake_id;
 return jsonb_build_object('stocktake_id',p_stocktake_id,'status','posted','valuation_total',v_total,'shortage_value',v_shortage);
end $$;

revoke all on function public.erp_create_physical_stocktake(uuid,uuid,text,text,text) from public;
revoke all on function public.erp_post_physical_stocktake(uuid,text,uuid) from public;
grant execute on function public.erp_create_physical_stocktake(uuid,uuid,text,text,text) to authenticated;
grant execute on function public.erp_post_physical_stocktake(uuid,text,uuid) to authenticated;
