-- Persist unique, company-scoped policy codes for program and visual identity policies.
begin;
alter table public.erp_program_policies add column if not exists policy_code text;

-- Backfill the canonical program-policy numbering without changing row IDs or policy values.
with numbered(policy_key, seq) as (
 values
 ('ui_dimensions',1),('ui_reorder',2),('ui_layout_standard',3),('ui_dropdown_item_height',4),
 ('ui_field_label_alignment',5),('ui_mobile_header_compact',6),('fiscal_year',7),
 ('inventory_valuation',8),('inventory_count',9),('depreciation',10),('group_duplicate_items',11),
 ('zero_adjustment_only',12),('adjustment_sale_price',13),('inventory.stocktake.valuation_basis',14),
 ('balance_sale_price',15),('trader_market.sell_duration_hours',16),('trader_market.buy_duration_hours',17),
 ('trader_market.transfer_duration_hours',18),('trader_market.story_duration',19),
 ('trader_market.story_duration_unit',20),('customer_default_rep',21),('customer_default_price_policy',22),
 ('edit_other_user_document',23),('customer_shortages_to_invoice',24),('sales_invoice_audit',25),
 ('skip_quotation',26),('skip_sales_order',27),('skip_supply_order',28),('skip_purchase_order',29),
 ('supplier_bonus_variance',30),('national_id_required',31),('code_generation_registry',32)
)
update public.erp_program_policies p set policy_code='Pol'||lpad(n.seq::text,3,'0')
from numbered n where p.policy_key=n.policy_key and p.category <> 'الهوية البصرية';

-- Add the twelve visual identity policy records for every existing company, deriving values from its saved settings.
with identity_catalogue(policy_key, policy_code, name_ar, name_en) as (
 values
 ('visual_identity.program_name','Idn001','اسم البرنامج','Program name'),
 ('visual_identity.language','Idn002','لغة واجهة البرنامج','Program interface language'),
 ('visual_identity.logo','Idn003','شعار البرنامج','Program logo'),
 ('visual_identity.primary_color','Idn004','اللون الأساسي','Primary color'),
 ('visual_identity.secondary_color','Idn005','اللون الثانوي','Secondary color'),
 ('visual_identity.accent_color','Idn006','لون التمييز','Accent color'),
 ('visual_identity.background_color','Idn007','لون الخلفية','Background color'),
 ('visual_identity.heading_1','Idn008','العنوان الرئيسي','Main heading style'),
 ('visual_identity.heading_2','Idn009','العنوان الفرعي الأول','First subheading style'),
 ('visual_identity.heading_3','Idn010','العنوان الفرعي الثاني','Second subheading style'),
 ('visual_identity.heading_4','Idn011','العنوان الفرعي الثالث','Third subheading style'),
 ('visual_identity.heading_5','Idn012','النص والعناوين الصغيرة','Small text style')
)
insert into public.erp_program_policies(company_id,policy_key,policy_code,category,name_ar,name_en,is_enabled,apply_to_all,user_ids,policy_value)
select c.id,i.policy_key,i.policy_code,'الهوية البصرية',i.name_ar,i.name_en,true,true,'[]'::jsonb,
case i.policy_key
 when 'visual_identity.program_name' then coalesce(s.program_name,'سلسلة')
 when 'visual_identity.language' then coalesce(s.language_code,'ar')
 when 'visual_identity.logo' then case when s.logo_base64 is null then '' else 'مخزن في إعدادات الهوية' end
 when 'visual_identity.primary_color' then coalesce(s.identity_primary_color,'#3E007D')
 when 'visual_identity.secondary_color' then coalesce(s.identity_secondary_color,'#FFA015')
 when 'visual_identity.accent_color' then coalesce(s.identity_accent_color,'#FF27C3')
 when 'visual_identity.background_color' then coalesce(s.identity_background_color,'#FFFFFF')
 else coalesce((select style::text from jsonb_array_elements(coalesce(s.heading_styles,'[]'::jsonb)) style where style->>'key'=replace(i.policy_key,'visual_identity.','') limit 1),'{}')
end
from public.erp_companies c cross join identity_catalogue i
left join public.erp_program_settings s on s.company_id=c.id
on conflict(company_id,policy_key) do nothing;

with identity_codes(policy_key,policy_code) as (
 values
 ('visual_identity.program_name','Idn001'),('visual_identity.language','Idn002'),
 ('visual_identity.logo','Idn003'),('visual_identity.primary_color','Idn004'),
 ('visual_identity.secondary_color','Idn005'),('visual_identity.accent_color','Idn006'),
 ('visual_identity.background_color','Idn007'),('visual_identity.heading_1','Idn008'),
 ('visual_identity.heading_2','Idn009'),('visual_identity.heading_3','Idn010'),
 ('visual_identity.heading_4','Idn011'),('visual_identity.heading_5','Idn012')
)
update public.erp_program_policies p set policy_code=i.policy_code
from identity_codes i where p.policy_key=i.policy_key and p.category='الهوية البصرية';

alter table public.erp_program_policies alter column policy_code set not null;
create unique index if not exists erp_program_policies_company_policy_code_uidx
 on public.erp_program_policies(company_id,policy_code);

create or replace function public.erp_assign_program_policy_code()
returns trigger language plpgsql set search_path = '' as $$
declare v_seq integer; v_max integer;
begin
 if new.policy_code is not null and btrim(new.policy_code) <> '' then return new; end if;
 if new.category='الهوية البصرية' then
   v_seq:=case new.policy_key
    when 'visual_identity.program_name' then 1 when 'visual_identity.language' then 2
    when 'visual_identity.logo' then 3 when 'visual_identity.primary_color' then 4
    when 'visual_identity.secondary_color' then 5 when 'visual_identity.accent_color' then 6
    when 'visual_identity.background_color' then 7 when 'visual_identity.heading_1' then 8
    when 'visual_identity.heading_2' then 9 when 'visual_identity.heading_3' then 10
    when 'visual_identity.heading_4' then 11 when 'visual_identity.heading_5' then 12 else null end;
   if v_seq is not null then new.policy_code:='Idn'||lpad(v_seq::text,3,'0'); end if;
 else
   v_seq:=case new.policy_key
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
   if v_seq is not null then new.policy_code:='Pol'||lpad(v_seq::text,3,'0'); end if;
   if new.policy_code is null then
     perform pg_advisory_xact_lock(hashtextextended(new.company_id::text||':program-policy-code',0));
     select coalesce(max(substring(policy_code from 4)::integer),0) into v_max
       from public.erp_program_policies where company_id=new.company_id and policy_code ~ '^Pol[0-9]+$';
     new.policy_code:='Pol'||lpad((v_max+1)::text,3,'0');
   end if;
 end if;
 if new.policy_code is null or btrim(new.policy_code)='' then
   raise exception 'لا يوجد كود سياسة معرف للمفتاح %',new.policy_key;
 end if;
 return new;
end $$;
drop trigger if exists erp_program_policies_assign_code on public.erp_program_policies;
create trigger erp_program_policies_assign_code before insert or update of policy_key,category,policy_code
 on public.erp_program_policies for each row execute function public.erp_assign_program_policy_code();
revoke all on function public.erp_assign_program_policy_code() from public,anon,authenticated;
commit;
