-- Attach customer code generation to the geographic tree used by the ERP screen.
alter table public.erp_parties
  add column if not exists geographic_area_id uuid null
  references public.erp_geographic_data(id) on delete set null;
create index if not exists idx_erp_parties_geographic_area
  on public.erp_parties(company_id, geographic_area_id)
  where geographic_area_id is not null;

create or replace function public.erp_assign_customer_geo_code()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_geo_code text; v_prefix text:='Cus'; v_digits integer:=4; v_policy text; v_max bigint; v_lock text;
begin
 if coalesce(new.party_kind,'')<>'customer' or nullif(new.party_code,'') is not null then return new; end if;
 if new.geographic_area_id is null then raise exception 'اختيار المنطقة مطلوب لتوليد كود العميل المرتبط بالتقسيم الجغرافي'; end if;
 select hierarchical_code into v_geo_code from public.erp_geographic_data where id=new.geographic_area_id and company_id=new.company_id and level='area' and is_active=true;
 if v_geo_code is null or v_geo_code !~ '^[0-9]{8}$' then raise exception 'المنطقة المختارة لا تحتوي على كود جغرافي صحيح من 8 أرقام'; end if;
 select policy_value into v_policy from public.erp_program_policies where company_id=new.company_id and policy_key='code_generation_registry' limit 1;
 if v_policy is not null and left(v_policy,1)='{' then
  v_prefix:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,prefix}',''),'Cus');
  v_digits:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,digits}','')::integer,4);
 end if;
 if v_prefix<>'Cus' or v_digits<1 or v_digits>12 then raise exception 'سياسة كود العميل يجب أن تستخدم البادئة Cus وعدد خانات من 1 إلى 12'; end if;
 v_lock:=new.company_id::text||':customer:'||new.geographic_area_id::text;
 perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
 select coalesce(max(substring(party_code from (length(v_prefix||v_geo_code)+1))::bigint),0) into v_max
 from public.erp_parties where company_id=new.company_id and party_kind='customer'
 and geographic_area_id=new.geographic_area_id and party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]+$');
 if coalesce(v_max,0)+1>=power(10::numeric,v_digits) then raise exception 'انتهت خانات تسلسل العملاء داخل هذه المنطقة؛ زد عدد الخانات من سياسات التكويد'; end if;
 new.party_code:=v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
 return new;
end;
$$;

create or replace function public.erp_preview_next_customer_geo_code(p_company_id uuid,p_geo_area_id uuid)
returns text language plpgsql security definer set search_path=''
as $$
declare v_geo_code text; v_prefix text:='Cus'; v_digits integer:=4; v_policy text; v_max bigint;
begin
 if auth.uid() is null or not public.erp_user_can_access_company(p_company_id) then raise exception 'غير مصرح بمعاينة أكواد هذه الشركة'; end if;
 select hierarchical_code into v_geo_code from public.erp_geographic_data where id=p_geo_area_id and company_id=p_company_id and level='area' and is_active=true;
 if v_geo_code is null or v_geo_code !~ '^[0-9]{8}$' then raise exception 'اختر منطقة فعالة لها كود جغرافي من 8 أرقام'; end if;
 select policy_value into v_policy from public.erp_program_policies where company_id=p_company_id and policy_key='code_generation_registry' limit 1;
 if v_policy is not null and left(v_policy,1)='{' then
  v_prefix:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,prefix}',''),'Cus');
  v_digits:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,digits}','')::integer,4);
 end if;
 select coalesce(max(substring(party_code from (length(v_prefix||v_geo_code)+1))::bigint),0) into v_max
 from public.erp_parties where company_id=p_company_id and party_kind='customer'
 and geographic_area_id=p_geo_area_id and party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]+$');
 return v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
end;
$$;
grant execute on function public.erp_preview_next_customer_geo_code(uuid,uuid) to authenticated;
