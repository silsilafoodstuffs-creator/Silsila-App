create or replace function public.erp_seed_default_user_types()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.erp_user_types(company_id,name_ar,name_en,is_active,show_at_login,description)
  values
    (new.id,'ادمن','Admin',true,false,'إدارة النظام والصلاحيات'),
    (new.id,'مورد','Supplier',true,true,'توريد الأصناف والأسعار'),
    (new.id,'عميل','Customer',true,true,'شراء الأصناف ومتابعة الطلبات'),
    (new.id,'شركة شحن','Shipping Company',true,true,'إدارة الشحن والتوصيل'),
    (new.id,'مندوب','Sales Representative',true,true,'البيع والتوزيع والتحصيل'),
    (new.id,'موظف','Employee',false,false,'حسابات الموظفين الداخلية')
  on conflict(company_id,name_ar) do nothing;
  return new;
end;
$$;