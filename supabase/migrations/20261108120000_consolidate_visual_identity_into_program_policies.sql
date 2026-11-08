-- Consolidate project name/logo into the program policies and standardize legacy identity policy codes.
begin;

create or replace function public.erp_assign_program_policy_code()
returns trigger language plpgsql set search_path = '' as $$
declare v_seq integer; v_max integer;
begin
 if new.policy_code is not null and btrim(new.policy_code) <> '' then return new; end if;
 if new.category = 'الهوية البصرية' then
   v_seq := case new.policy_key
    when 'visual_identity.program_name' then 42
    when 'visual_identity.logo' then 43
    when 'visual_identity.language' then 44
    when 'visual_identity.primary_color' then 45
    when 'visual_identity.secondary_color' then 46
    when 'visual_identity.accent_color' then 47
    when 'visual_identity.background_color' then 48
    when 'visual_identity.heading_1' then 49
    when 'visual_identity.heading_2' then 50
    when 'visual_identity.heading_3' then 51
    when 'visual_identity.heading_4' then 52
    when 'visual_identity.heading_5' then 53
    else null end;
   if v_seq is not null then new.policy_code := 'Pol'||lpad(v_seq::text,3,'0'); end if;
 else
   v_seq := case new.policy_key
    when 'visual_identity.program_name' then 42
    when 'visual_identity.logo' then 43
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

insert into public.erp_program_policies
  (company_id,policy_key,policy_code,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value)
select c.id,'visual_identity.program_name','Pol042','برمجية','اسم المشروع','Project name',true,true,'[]'::jsonb,
       coalesce(nullif(s.program_name,''),'سلسلة')
from public.erp_companies c
left join public.erp_program_settings s on s.company_id=c.id
on conflict(company_id,policy_key) do update set
  policy_code='Pol042',category='برمجية',name_ar='اسم المشروع',name_en='Project name',
  is_enabled=true,apply_to_all=true,user_ids='[]'::jsonb,
  policy_value=coalesce(nullif(excluded.policy_value,''),'سلسلة');

insert into public.erp_program_policies
  (company_id,policy_key,policy_code,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value)
select c.id,'visual_identity.logo','Pol043','برمجية','شعار المشروع','Project logo',true,true,'[]'::jsonb,
       case when s.logo_base64 is null then '' else 'تم تحديد الشعار' end
from public.erp_companies c
left join public.erp_program_settings s on s.company_id=c.id
on conflict(company_id,policy_key) do update set
  policy_code='Pol043',category='برمجية',name_ar='شعار المشروع',name_en='Project logo',
  is_enabled=true,apply_to_all=true,user_ids='[]'::jsonb,
  policy_value=excluded.policy_value;

update public.erp_program_policies
set policy_code = case policy_key
 when 'visual_identity.language' then 'Pol044'
 when 'visual_identity.primary_color' then 'Pol045'
 when 'visual_identity.secondary_color' then 'Pol046'
 when 'visual_identity.accent_color' then 'Pol047'
 when 'visual_identity.background_color' then 'Pol048'
 when 'visual_identity.heading_1' then 'Pol049'
 when 'visual_identity.heading_2' then 'Pol050'
 when 'visual_identity.heading_3' then 'Pol051'
 when 'visual_identity.heading_4' then 'Pol052'
 when 'visual_identity.heading_5' then 'Pol053'
 else policy_code end
where category='الهوية البصرية'
  and policy_key in ('visual_identity.language','visual_identity.primary_color','visual_identity.secondary_color',
    'visual_identity.accent_color','visual_identity.background_color','visual_identity.heading_1',
    'visual_identity.heading_2','visual_identity.heading_3','visual_identity.heading_4','visual_identity.heading_5');

commit;
