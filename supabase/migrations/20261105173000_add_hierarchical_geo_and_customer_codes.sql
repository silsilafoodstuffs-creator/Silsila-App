alter table public.erp_geographic_data add column if not exists hierarchical_code text;

with egypt as (
  select company_id,country_code from public.erp_countries where name_ar='مصر' and is_active=true
), gov as (
  select g.id,e.country_code||lpad(row_number() over(partition by g.company_id order by g.geo_code,g.name_ar,g.id)::text,2,'0') path_code
  from public.erp_geographic_data g join egypt e using(company_id) where g.level='governorate'
)
update public.erp_geographic_data g set hierarchical_code=gov.path_code from gov where g.id=gov.id;

with numbered as (
  select d.id,p.hierarchical_code||lpad(row_number() over(partition by d.parent_id order by d.geo_code,d.name_ar,d.id)::text,2,'0') path_code
  from public.erp_geographic_data d join public.erp_geographic_data p on p.id=d.parent_id and p.company_id=d.company_id
  where d.level='district' and p.level='governorate' and p.hierarchical_code is not null
)
update public.erp_geographic_data d set hierarchical_code=n.path_code from numbered n where d.id=n.id;

with numbered as (
  select a.id,p.hierarchical_code||lpad(row_number() over(partition by a.parent_id order by a.geo_code,a.name_ar,a.id)::text,2,'0') path_code
  from public.erp_geographic_data a join public.erp_geographic_data p on p.id=a.parent_id and p.company_id=a.company_id
  where a.level='area' and p.level='district' and p.hierarchical_code is not null
)
update public.erp_geographic_data a set hierarchical_code=n.path_code from numbered n where a.id=n.id;

create unique index if not exists erp_geographic_data_company_hierarchical_code_uq
on public.erp_geographic_data(company_id,hierarchical_code) where hierarchical_code is not null;

create or replace function public.erp_assign_geo_hierarchical_code()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_parent_code text; v_country_code text; v_next integer; v_lock text;
begin
 if tg_op='UPDATE' and new.parent_id is not distinct from old.parent_id and new.level is not distinct from old.level and new.hierarchical_code is not null then return new; end if;
 if new.level='governorate' then
  if new.parent_id is not null then raise exception 'المحافظة يجب أن تكون مستوى رئيسيًا دون أب جغرافي'; end if;
  select country_code into v_country_code from public.erp_countries where company_id=new.company_id and name_ar='مصر' and is_active=true order by created_at limit 1;
  if v_country_code is null or v_country_code !~ '^[0-9]{2}$' then raise exception 'يجب تسجيل كود مصر المكون من رقمين في تبويب بيانات الدول أولاً'; end if;
  v_lock:=new.company_id::text||':governorate'; perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
  select coalesce(max(right(hierarchical_code,2)::integer),0)+1 into v_next from public.erp_geographic_data where company_id=new.company_id and level='governorate' and hierarchical_code ~ ('^'||v_country_code||'[0-9]{2}$');
  if v_next>99 then raise exception 'تم استنفاد أكواد المحافظات'; end if;
  new.hierarchical_code:=v_country_code||lpad(v_next::text,2,'0');
 elsif new.level in ('district','area') then
  if new.parent_id is null then raise exception 'يجب ربط المركز/الحي أو المنطقة بالمستوى الجغرافي الأعلى'; end if;
  select hierarchical_code into v_parent_code from public.erp_geographic_data where id=new.parent_id and company_id=new.company_id and level=case when new.level='district' then 'governorate' else 'district' end;
  if v_parent_code is null then raise exception 'التسلسل الجغرافي غير صحيح: اربط كل مستوى بأبيه الصحيح'; end if;
  v_lock:=new.company_id::text||':'||new.parent_id::text||':'||new.level; perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
  select coalesce(max(right(hierarchical_code,2)::integer),0)+1 into v_next from public.erp_geographic_data where company_id=new.company_id and parent_id=new.parent_id and level=new.level and hierarchical_code like v_parent_code||'__';
  if v_next>99 then raise exception 'تم استنفاد الأكواد التابعة لهذا المستوى'; end if;
  new.hierarchical_code:=v_parent_code||lpad(v_next::text,2,'0');
 else raise exception 'مستوى جغرافي غير مدعوم: %',new.level;
 end if;
 return new;
end;
$$;

drop trigger if exists erp_geographic_data_hierarchical_code on public.erp_geographic_data;
create trigger erp_geographic_data_hierarchical_code before insert or update of parent_id,level on public.erp_geographic_data for each row execute function public.erp_assign_geo_hierarchical_code();

create or replace function public.erp_assign_customer_geo_code()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_geo_code text; v_prefix text:='Cus'; v_digits integer:=4; v_policy text; v_max bigint; v_lock text;
begin
 if coalesce(new.party_kind,'')<>'customer' or nullif(new.party_code,'') is not null then return new; end if;
 if new.geo_area_id is null then raise exception 'اختيار المنطقة مطلوب لتوليد كود العميل المرتبط بالتقسيم الجغرافي'; end if;
 select hierarchical_code into v_geo_code from public.erp_geographic_data where id=new.geo_area_id and company_id=new.company_id and level='area' and is_active=true;
 if v_geo_code is null or v_geo_code !~ '^[0-9]{8}$' then raise exception 'المنطقة المختارة لا تحتوي على كود جغرافي صحيح من 8 أرقام'; end if;
 select policy_value into v_policy from public.erp_program_policies where company_id=new.company_id and policy_key='code_generation_registry' limit 1;
 if v_policy is not null and left(v_policy,1)='{' then
  v_prefix:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,prefix}',''),'Cus');
  v_digits:=coalesce(nullif(v_policy::jsonb #>> '{types,customer,digits}','')::integer,4);
 end if;
 if v_prefix<>'Cus' or v_digits<1 or v_digits>12 then raise exception 'سياسة كود العميل يجب أن تستخدم البادئة Cus وعدد خانات من 1 إلى 12'; end if;
 v_lock:=new.company_id::text||':customer:'||new.geo_area_id::text; perform pg_advisory_xact_lock(hashtextextended(v_lock,0));
 select coalesce(max(substring(party_code from (length(v_prefix||v_geo_code)+1))::bigint),0) into v_max
 from public.erp_parties where company_id=new.company_id and party_kind='customer' and geo_area_id=new.geo_area_id and party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]+$');
 if coalesce(v_max,0)+1>=power(10::numeric,v_digits) then raise exception 'انتهت خانات تسلسل العملاء داخل هذه المنطقة؛ زد عدد الخانات من سياسات التكويد'; end if;
 new.party_code:=v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
 return new;
end;
$$;

drop trigger if exists a_erp_parties_geo_customer_code on public.erp_parties;
create trigger a_erp_parties_geo_customer_code before insert on public.erp_parties for each row execute function public.erp_assign_customer_geo_code();

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
 from public.erp_parties where company_id=p_company_id and party_kind='customer' and geo_area_id=p_geo_area_id and party_code ~ ('^'||v_prefix||v_geo_code||'[0-9]+$');
 return v_prefix||v_geo_code||lpad((coalesce(v_max,0)+1)::text,v_digits,'0');
end;
$$;
grant execute on function public.erp_preview_next_customer_geo_code(uuid,uuid) to authenticated;
