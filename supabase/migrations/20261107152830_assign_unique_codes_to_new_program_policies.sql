create or replace function public.erp_assign_program_policy_code()
returns trigger language plpgsql set search_path = '' as $$
declare v_seq integer; v_max integer;
begin
 if new.policy_code is not null and btrim(new.policy_code) <> '' then return new; end if;
 if new.category = 'الهوية البصرية' then
   v_seq := case new.policy_key
    when 'visual_identity.program_name' then 1 when 'visual_identity.language' then 2
    when 'visual_identity.logo' then 3 when 'visual_identity.primary_color' then 4
    when 'visual_identity.secondary_color' then 5 when 'visual_identity.accent_color' then 6
    when 'visual_identity.background_color' then 7 when 'visual_identity.heading_1' then 8
    when 'visual_identity.heading_2' then 9 when 'visual_identity.heading_3' then 10
    when 'visual_identity.heading_4' then 11 when 'visual_identity.heading_5' then 12 else null end;
   if v_seq is not null then new.policy_code := 'Idn'||lpad(v_seq::text,3,'0'); end if;
 else
   v_seq := case new.policy_key
    when 'ui_dimensions' then 1 when 'ui_reorder' then 2 when 'ui_layout_standard' then 3
    when 'ui_dropdown_item_height' then 4 when 'ui_field_label_alignment' then 5
    when 'ui_mobile_header_compact' then 6 when 'fiscal_year' then 7
    when 'inventory_valuation' then 8 when 'inventory_count' then 9 when 'depreciation' then 10
    when 'group_duplicate_items' then 11 when 'zero_adjustment_only' then 12
    when 'adjustment_sale_price' then 13 when 'inventory.stocktake.valuation_basis' then 14
    when 'balance_sale_price' then 15 when 'trader_market.sell_duration_hours' then 16
    when 'trader_market.buy_duration_hours' then 17 when 'trader_market.transfer_duration_hours' then 18
    when 'trader_market.story_duration' then 19 when 'trader_market.story_duration_unit' then 20
    when 'customer_default_rep' then 21 when 'customer_default_price_policy' then 22
    when 'edit_other_user_document' then 23 when 'customer_shortages_to_invoice' then 24
    when 'sales_invoice_audit' then 25 when 'skip_quotation' then 26 when 'skip_sales_order' then 27
    when 'skip_supply_order' then 28 when 'skip_purchase_order' then 29
    when 'supplier_bonus_variance' then 30 when 'national_id_required' then 31
    when 'code_generation_registry' then 32 else null end;
   if v_seq is not null then new.policy_code := 'Pol'||lpad(v_seq::text,3,'0'); end if;
   if new.policy_code is null then
     perform pg_advisory_xact_lock(hashtextextended(new.company_id::text || ':program-policy-code',0));
     select coalesce(max(substring(policy_code from 4)::integer),0) into v_max
       from public.erp_program_policies
       where company_id=new.company_id and policy_code ~ '^Pol[0-9]+$';
     new.policy_code := 'Pol'||lpad((v_max+1)::text,3,'0');
   end if;
 end if;
 if new.policy_code is null or btrim(new.policy_code) = '' then
   raise exception 'لا يوجد كود سياسة معرف للمفتاح %', new.policy_key;
 end if;
 return new;
end $$;