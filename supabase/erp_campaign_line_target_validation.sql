create or replace function public.erp_validate_campaign_sales_line()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_campaign_item public.erp_sales_campaign_items%rowtype;
  v_campaign public.erp_sales_campaigns%rowtype;
  v_company uuid;
  v_status text;
  v_customer uuid;
  v_warehouse uuid;
  v_branch uuid;
  v_governorate text;
  v_district text;
  v_area text;
  v_center text;
  v_customer_type text;
begin
  if new.campaign_item_id is null then return new; end if;
  select d.company_id,d.status,d.customer_id,d.warehouse_id into v_company,v_status,v_customer,v_warehouse
    from public.erp_sales_documents d where d.id=new.document_id;
  if v_company is null or v_status <> 'draft' then
    raise exception 'لا يمكن ربط عرض إلا ببند في مسودة مبيعات.';
  end if;
  select * into v_campaign_item from public.erp_sales_campaign_items
    where id=new.campaign_item_id for update;
  if not found or not v_campaign_item.is_active or v_campaign_item.company_id<>v_company or v_campaign_item.item_id<>new.item_id then
    raise exception 'بند العرض غير نشط أو لا يطابق الصنف والشركة.';
  end if;
  select * into v_campaign from public.erp_sales_campaigns where id=v_campaign_item.campaign_id;
  if not found or not v_campaign.is_active or v_campaign.company_id<>v_company
     or v_campaign.start_date>current_date or v_campaign.end_date<current_date then
    raise exception 'العرض غير نشط أو خارج فترة السريان.';
  end if;
  if v_campaign.owner_party_id is not null and v_campaign.owner_party_id is distinct from v_customer then
    raise exception 'هذا العرض غير مخصص للعميل المحدد.';
  end if;
  if jsonb_array_length(v_campaign.target_customer_ids)>0 and
     not (v_campaign.target_customer_ids ? coalesce(v_customer::text,'')) then
    raise exception 'العميل غير مشمول في نطاق العرض.';
  end if;
  if jsonb_array_length(v_campaign.target_warehouse_ids)>0 and
     not (v_campaign.target_warehouse_ids ? coalesce(v_warehouse::text,'')) then
    raise exception 'المخزن غير مشمول في نطاق العرض.';
  end if;
  select branch_id into v_branch from public.erp_warehouses where id=v_warehouse and company_id=v_company;
  if jsonb_array_length(v_campaign.target_branch_ids)>0 and
     not (v_campaign.target_branch_ids ? coalesce(v_branch::text,'')) then
    raise exception 'الفرع غير مشمول في نطاق العرض.';
  end if;
  select governorate,district,area,center,customer_type
    into v_governorate,v_district,v_area,v_center,v_customer_type
    from public.erp_parties where id=v_customer and company_id=v_company;
  if jsonb_array_length(v_campaign.target_governorates)>0 and not (v_campaign.target_governorates ? coalesce(v_governorate,'')) then
    raise exception 'محافظة العميل غير مشمولة في العرض.';
  end if;
  if jsonb_array_length(v_campaign.target_districts)>0 and not (v_campaign.target_districts ? coalesce(v_district,'')) then
    raise exception 'مركز/حي العميل غير مشمول في العرض.';
  end if;
  if jsonb_array_length(v_campaign.target_areas)>0 and not (v_campaign.target_areas ? coalesce(v_area,'')) then
    raise exception 'منطقة العميل غير مشمولة في العرض.';
  end if;
  if jsonb_array_length(v_campaign.target_centers)>0 and not (v_campaign.target_centers ? coalesce(v_center,'')) then
    raise exception 'مركز العميل غير مشمول في العرض.';
  end if;
  if jsonb_array_length(v_campaign.target_customer_types)>0 and not (v_campaign.target_customer_types ? coalesce(v_customer_type,'')) then
    raise exception 'تصنيف العميل غير مشمول في العرض.';
  end if;
  if v_campaign_item.remaining_quantity is not null and
     coalesce(new.base_quantity,new.quantity)>v_campaign_item.remaining_quantity then
    raise exception 'الكمية المطلوبة تتجاوز المتبقي في العرض (%).',v_campaign_item.remaining_quantity;
  end if;
  return new;
end;
$$;
