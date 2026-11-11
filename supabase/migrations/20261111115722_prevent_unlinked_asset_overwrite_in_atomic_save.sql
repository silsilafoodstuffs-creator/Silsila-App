CREATE OR REPLACE FUNCTION public.erp_save_business_suite_simple_record_atomic(p_parent_record_id uuid, p_parent jsonb, p_operational jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_company_id uuid;
  v_module_key text;
  v_record_type text;
  v_record_code text;
  v_name text;
  v_status text;
  v_record_date date;
  v_due_date date;
  v_counterparty text;
  v_amount numeric(18,3);
  v_quantity numeric(18,3);
  v_details jsonb;
  v_old_details jsonb := '{}'::jsonb;
  v_old_operational_table text;
  v_operational_id uuid;
  v_operational_table text;
  v_parent_id uuid;
  v_count integer := 0;
  v_role_ok boolean := false;
  v_party_id uuid;
  v_ticket_id uuid;
  v_lead_id uuid;
  v_account_id uuid;
  v_project_id uuid;
  v_order_id uuid;
  v_item_id uuid;
  v_has_depreciation boolean := false;
  v_asset public.erp_fixed_assets%rowtype;
begin
  if v_user_id is null then
    raise exception 'يلزم تسجيل الدخول' using errcode='28000';
  end if;
  if p_parent is null or jsonb_typeof(p_parent)<>'object'
     or p_operational is null or jsonb_typeof(p_operational)<>'object' then
    raise exception 'بيانات السجل العام أو التشغيلي غير صحيحة' using errcode='22023';
  end if;

  v_company_id:=nullif(p_parent->>'company_id','')::uuid;
  v_module_key:=p_parent->>'module_key';
  v_record_type:=p_parent->>'record_type';
  v_record_code:=nullif(btrim(p_parent->>'record_code'),'');
  v_name:=nullif(btrim(p_parent->>'name'),'');
  v_status:=coalesce(nullif(p_parent->>'status',''),'draft');
  v_record_date:=nullif(p_parent->>'record_date','')::date;
  v_due_date:=nullif(p_parent->>'due_date','')::date;
  v_counterparty:=nullif(btrim(p_parent->>'counterparty'),'');
  v_amount:=coalesce(nullif(p_parent->>'amount','')::numeric,0);
  v_quantity:=coalesce(nullif(p_parent->>'quantity','')::numeric,0);
  v_details:=coalesce(p_parent->'details','{}'::jsonb);

  if v_company_id is null or v_record_code is null or v_name is null
     or jsonb_typeof(v_details)<>'object' then
    raise exception 'الشركة والكود والاسم وتفاصيل السجل مطلوبة' using errcode='22023';
  end if;
  if v_amount<0 or v_quantity<0 then
    raise exception 'القيمة والكمية لا يمكن أن تكونا سالبتين' using errcode='22023';
  end if;
  if v_record_date is not null and v_due_date is not null and v_due_date<v_record_date then
    raise exception 'تاريخ الاستحقاق لا يمكن أن يسبق تاريخ السجل' using errcode='22023';
  end if;

  if not (
    public.erp_user_has_company_role(v_company_id,array['owner','admin','manager']::text[])
    or exists (
      select 1 from public.erp_company_member_profiles p
      where p.company_id=v_company_id and p.user_id=v_user_id
    )
  ) then
    raise exception 'لا تملك صلاحية حفظ سجلات هذا المجال في الشركة المحددة' using errcode='42501';
  end if;

  if (v_module_key,v_record_type) not in (
    ('fixed_assets','asset_category'),
    ('manufacturing','work_center'),
    ('customer_service','opportunity'),
    ('customer_service','sla_policy'),
    ('customer_service','ticket'),
    ('customer_service','field_task'),
    ('customer_service','activity'),
    ('fixed_assets','asset'),
    ('manufacturing','production_quality_check'),
    ('manufacturing','production_variance'),
    ('contracting','project'),
    ('contracting','site_report')
  ) then
    raise exception 'نوع السجل غير مدعوم في مسار الحفظ الذري المحدد' using errcode='22023';
  end if;

  if p_parent_record_id is not null then
    select r.details into v_old_details
    from public.erp_business_suite_records r
    where r.id=p_parent_record_id
      and r.company_id=v_company_id
      and r.module_key=v_module_key
      and r.record_type=v_record_type
    for update;
    if not found then
      raise exception 'السجل العام المراد تعديله غير موجود داخل الشركة' using errcode='P0002';
    end if;
  end if;

  v_old_operational_table:=v_old_details->>'_operational_table';
  v_operational_id:=nullif(v_old_details->>'_operational_id','')::uuid;

  case
    when v_module_key='fixed_assets' and v_record_type='asset_category' then
      v_operational_table:='erp_asset_categories';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط فئة الأصل غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      if nullif(p_operational->>'depreciation_method','') not in ('straight_line','declining_balance','units_of_production','none')
         or coalesce(nullif(p_operational->>'useful_life_months','')::integer,60)<0
         or coalesce(nullif(p_operational->>'residual_percent','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'residual_percent','')::numeric,0)>100 then
        raise exception 'طريقة الإهلاك أو العمر أو النسبة التخريدية غير صالحة' using errcode='22023';
      end if;
      for v_account_id in
        select x.account_id
        from (values
          (nullif(p_operational->>'asset_account_id','')::uuid),
          (nullif(p_operational->>'accumulated_account_id','')::uuid),
          (nullif(p_operational->>'expense_account_id','')::uuid)
        ) as x(account_id)
        where x.account_id is not null
      loop
        if not exists(select 1 from public.erp_accounts a where a.id=v_account_id and a.company_id=v_company_id) then
          raise exception 'أحد الحسابات المرتبطة بفئة الأصل لا يتبع الشركة المحددة' using errcode='23503';
        end if;
      end loop;
      if v_operational_id is not null then
        update public.erp_asset_categories
        set category_code=coalesce(nullif(p_operational->>'category_code',''),v_record_code),
            name=v_name,
            depreciation_method=p_operational->>'depreciation_method',
            useful_life_months=coalesce(nullif(p_operational->>'useful_life_months','')::integer,60),
            residual_percent=coalesce(nullif(p_operational->>'residual_percent','')::numeric,0),
            asset_account_id=nullif(p_operational->>'asset_account_id','')::uuid,
            accumulated_account_id=nullif(p_operational->>'accumulated_account_id','')::uuid,
            expense_account_id=nullif(p_operational->>'expense_account_id','')::uuid,
            is_active=coalesce((p_operational->>'is_active')::boolean,true),
            updated_at=now()
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'فئة الأصل المرتبطة غير موجودة داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_asset_categories(
          company_id,category_code,name,depreciation_method,useful_life_months,
          residual_percent,asset_account_id,accumulated_account_id,expense_account_id,is_active
        ) values (
          v_company_id,coalesce(nullif(p_operational->>'category_code',''),v_record_code),v_name,
          p_operational->>'depreciation_method',
          coalesce(nullif(p_operational->>'useful_life_months','')::integer,60),
          coalesce(nullif(p_operational->>'residual_percent','')::numeric,0),
          nullif(p_operational->>'asset_account_id','')::uuid,
          nullif(p_operational->>'accumulated_account_id','')::uuid,
          nullif(p_operational->>'expense_account_id','')::uuid,
          coalesce((p_operational->>'is_active')::boolean,true)
        )
        on conflict(company_id,category_code) do update
        set name=excluded.name,depreciation_method=excluded.depreciation_method,
            useful_life_months=excluded.useful_life_months,residual_percent=excluded.residual_percent,
            asset_account_id=excluded.asset_account_id,accumulated_account_id=excluded.accumulated_account_id,
            expense_account_id=excluded.expense_account_id,is_active=excluded.is_active,updated_at=now()
        returning id into v_operational_id;
      end if;

    when v_module_key='manufacturing' and v_record_type='work_center' then
      v_operational_table:='erp_manufacturing_work_centers';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط مركز العمل غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      if coalesce(nullif(p_operational->>'capacity_per_hour','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'hourly_cost','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'setup_minutes','')::integer,0)<0 then
        raise exception 'طاقة مركز العمل وتكلفته وزمن التجهيز يجب ألا تكون سالبة' using errcode='22023';
      end if;
      if v_operational_id is not null then
        update public.erp_manufacturing_work_centers
        set center_code=coalesce(nullif(p_operational->>'center_code',''),v_record_code),
            name=v_name,
            center_type=coalesce(nullif(p_operational->>'center_type',''),'production_line'),
            capacity_per_hour=coalesce(nullif(p_operational->>'capacity_per_hour','')::numeric,0),
            hourly_cost=coalesce(nullif(p_operational->>'hourly_cost','')::numeric,0),
            setup_minutes=coalesce(nullif(p_operational->>'setup_minutes','')::integer,0),
            location=nullif(p_operational->>'location',''),
            supervisor=nullif(p_operational->>'supervisor',''),
            is_active=coalesce((p_operational->>'is_active')::boolean,true),
            updated_at=now()
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'مركز العمل المرتبط غير موجود داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_manufacturing_work_centers(
          company_id,center_code,name,center_type,capacity_per_hour,hourly_cost,
          setup_minutes,location,supervisor,is_active
        ) values (
          v_company_id,coalesce(nullif(p_operational->>'center_code',''),v_record_code),v_name,
          coalesce(nullif(p_operational->>'center_type',''),'production_line'),
          coalesce(nullif(p_operational->>'capacity_per_hour','')::numeric,0),
          coalesce(nullif(p_operational->>'hourly_cost','')::numeric,0),
          coalesce(nullif(p_operational->>'setup_minutes','')::integer,0),
          nullif(p_operational->>'location',''),nullif(p_operational->>'supervisor',''),
          coalesce((p_operational->>'is_active')::boolean,true)
        )
        on conflict(company_id,center_code) do update
        set name=excluded.name,center_type=excluded.center_type,
            capacity_per_hour=excluded.capacity_per_hour,hourly_cost=excluded.hourly_cost,
            setup_minutes=excluded.setup_minutes,location=excluded.location,supervisor=excluded.supervisor,
            is_active=excluded.is_active,updated_at=now()
        returning id into v_operational_id;
      end if;

    when v_module_key='customer_service' and v_record_type='opportunity' then
      v_operational_table:='erp_crm_leads';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط فرصة العميل غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      v_party_id:=nullif(p_operational->>'party_id','')::uuid;
      if v_party_id is not null and not exists(
        select 1 from public.erp_parties p where p.id=v_party_id and p.company_id=v_company_id
      ) then
        raise exception 'العميل أو الجهة المرتبطة بالفرصة لا تتبع الشركة المحددة' using errcode='23503';
      end if;
      if coalesce(nullif(p_operational->>'probability','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'probability','')::numeric,0)>100
         or coalesce(nullif(p_operational->>'expected_revenue','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'stage',''),'new') not in ('new','qualified','proposal','negotiation','won','lost')
         or coalesce(nullif(p_operational->>'status',''),'open') not in ('open','won','lost','archived') then
        raise exception 'مرحلة الفرصة أو احتمالية الفوز أو الإيراد المتوقع غير صالح' using errcode='22023';
      end if;
      if v_operational_id is not null then
        update public.erp_crm_leads
        set lead_code=coalesce(nullif(p_operational->>'lead_code',''),v_record_code),
            title=v_name,party_id=v_party_id,
            contact_name=nullif(p_operational->>'contact_name',''),
            phone=nullif(p_operational->>'phone',''),
            email=nullif(p_operational->>'email',''),
            source=nullif(p_operational->>'source',''),
            stage=coalesce(nullif(p_operational->>'stage',''),'new'),
            probability=coalesce(nullif(p_operational->>'probability','')::numeric,0),
            expected_revenue=coalesce(nullif(p_operational->>'expected_revenue','')::numeric,0),
            expected_close_date=nullif(p_operational->>'expected_close_date','')::date,
            next_activity=nullif(p_operational->>'next_activity',''),
            status=coalesce(nullif(p_operational->>'status',''),'open'),
            updated_at=now()
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'فرصة العميل المرتبطة غير موجودة داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_crm_leads(
          company_id,lead_code,title,party_id,contact_name,phone,email,source,
          stage,probability,expected_revenue,expected_close_date,next_activity,status
        ) values(
          v_company_id,coalesce(nullif(p_operational->>'lead_code',''),v_record_code),v_name,v_party_id,
          nullif(p_operational->>'contact_name',''),nullif(p_operational->>'phone',''),
          nullif(p_operational->>'email',''),nullif(p_operational->>'source',''),
          coalesce(nullif(p_operational->>'stage',''),'new'),
          coalesce(nullif(p_operational->>'probability','')::numeric,0),
          coalesce(nullif(p_operational->>'expected_revenue','')::numeric,0),
          nullif(p_operational->>'expected_close_date','')::date,
          nullif(p_operational->>'next_activity',''),
          coalesce(nullif(p_operational->>'status',''),'open')
        )
        on conflict(company_id,lead_code) do update
        set title=excluded.title,party_id=excluded.party_id,contact_name=excluded.contact_name,
            phone=excluded.phone,email=excluded.email,source=excluded.source,stage=excluded.stage,
            probability=excluded.probability,expected_revenue=excluded.expected_revenue,
            expected_close_date=excluded.expected_close_date,next_activity=excluded.next_activity,
            status=excluded.status,updated_at=now()
        returning id into v_operational_id;
      end if;

    when v_module_key='customer_service' and v_record_type='sla_policy' then
      v_operational_table:='erp_service_sla_policies';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط سياسة SLA غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      if coalesce(nullif(p_operational->>'priority',''),'normal') not in ('low','normal','high','urgent')
         or coalesce(nullif(p_operational->>'first_response_minutes','')::integer,0)<=0
         or coalesce(nullif(p_operational->>'resolution_minutes','')::integer,0)<=0
         or (nullif(p_operational->>'escalation_minutes','') is not null and (p_operational->>'escalation_minutes')::integer<=0) then
        raise exception 'أولوية سياسة SLA أو أزمنة الاستجابة والحل والتصعيد غير صالحة' using errcode='22023';
      end if;
      if v_operational_id is not null then
        update public.erp_service_sla_policies
        set policy_code=coalesce(nullif(p_operational->>'policy_code',''),v_record_code),
            name=v_name,priority=coalesce(nullif(p_operational->>'priority',''),'normal'),
            first_response_minutes=(p_operational->>'first_response_minutes')::integer,
            resolution_minutes=(p_operational->>'resolution_minutes')::integer,
            escalation_minutes=nullif(p_operational->>'escalation_minutes','')::integer,
            is_active=coalesce((p_operational->>'is_active')::boolean,true),
            updated_at=now()
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'سياسة SLA المرتبطة غير موجودة داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_service_sla_policies(
          company_id,policy_code,name,priority,first_response_minutes,
          resolution_minutes,escalation_minutes,is_active
        ) values(
          v_company_id,coalesce(nullif(p_operational->>'policy_code',''),v_record_code),v_name,
          coalesce(nullif(p_operational->>'priority',''),'normal'),
          (p_operational->>'first_response_minutes')::integer,
          (p_operational->>'resolution_minutes')::integer,
          nullif(p_operational->>'escalation_minutes','')::integer,
          coalesce((p_operational->>'is_active')::boolean,true)
        )
        on conflict(company_id,policy_code) do update
        set name=excluded.name,priority=excluded.priority,
            first_response_minutes=excluded.first_response_minutes,
            resolution_minutes=excluded.resolution_minutes,
            escalation_minutes=excluded.escalation_minutes,
            is_active=excluded.is_active,updated_at=now()
        returning id into v_operational_id;
      end if;



    when v_module_key='fixed_assets' and v_record_type='asset' then
      v_operational_table:='erp_fixed_assets';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط الأصل الثابت غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;

      v_item_id:=nullif(p_operational->>'category_id','')::uuid;
      if v_item_id is not null and not exists (
        select 1 from public.erp_asset_categories c
        where c.id=v_item_id and c.company_id=v_company_id
      ) then
        raise exception 'فئة الأصل لا تتبع الشركة المحددة' using errcode='23503';
      end if;

      for v_account_id in
        select x.account_id
        from (values
          (nullif(p_operational->>'asset_account_id','')::uuid),
          (nullif(p_operational->>'accumulated_account_id','')::uuid),
          (nullif(p_operational->>'expense_account_id','')::uuid)
        ) as x(account_id)
        where x.account_id is not null
      loop
        if not exists (
          select 1 from public.erp_accounts a
          where a.id=v_account_id and a.company_id=v_company_id
        ) then
          raise exception 'أحد الحسابات المرتبطة بالأصل لا يتبع الشركة المحددة' using errcode='23503';
        end if;
      end loop;

      if coalesce(nullif(p_operational->>'acquisition_cost','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'residual_value','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'useful_life_months','')::integer,0)<=0
         or coalesce(nullif(p_operational->>'accumulated_depreciation','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'depreciation_method',''),'straight_line')
              not in ('straight_line','declining_balance','units_of_production','none')
         or coalesce(nullif(p_operational->>'status',''),'draft') not in ('draft','active') then
        raise exception 'بيانات تكلفة الأصل أو العمر أو طريقة الإهلاك أو الحالة غير صالحة' using errcode='22023';
      end if;
      if coalesce(nullif(p_operational->>'residual_value','')::numeric,0)>
         coalesce(nullif(p_operational->>'acquisition_cost','')::numeric,0) then
        raise exception 'القيمة التخريدية لا يمكن أن تتجاوز تكلفة اقتناء الأصل' using errcode='23514';
      end if;

      if v_operational_id is not null then
        select a.* into v_asset
        from public.erp_fixed_assets a
        where a.id=v_operational_id and a.company_id=v_company_id
        for update;
        if not found then
          raise exception 'الأصل المرتبط غير موجود داخل الشركة' using errcode='P0002';
        end if;
        if v_asset.status in ('disposed','written_off') then
          raise exception 'الأصل المستبعد أو المشطوب لا يمكن تعديله' using errcode='23514';
        end if;

        select exists(
          select 1 from public.erp_asset_depreciation_lines l
          where l.company_id=v_company_id and l.asset_id=v_operational_id
        ) into v_has_depreciation;

        if v_has_depreciation and (
          v_asset.acquisition_cost is distinct from coalesce(nullif(p_operational->>'acquisition_cost','')::numeric,0)
          or v_asset.residual_value is distinct from coalesce(nullif(p_operational->>'residual_value','')::numeric,0)
          or v_asset.useful_life_months is distinct from coalesce(nullif(p_operational->>'useful_life_months','')::integer,0)
          or v_asset.depreciation_method is distinct from coalesce(nullif(p_operational->>'depreciation_method',''),'straight_line')
          or v_asset.asset_account_id is distinct from nullif(p_operational->>'asset_account_id','')::uuid
          or v_asset.accumulated_account_id is distinct from nullif(p_operational->>'accumulated_account_id','')::uuid
          or v_asset.expense_account_id is distinct from nullif(p_operational->>'expense_account_id','')::uuid
        ) then
          raise exception 'للأصل جدول إهلاك موجود؛ لا يمكن تغيير بياناته المالية أو حساباته بعد بدء الإهلاك' using errcode='23514';
        end if;

        update public.erp_fixed_assets
        set category_id=v_item_id,
            asset_code=coalesce(nullif(p_operational->>'asset_code',''),v_record_code),
            name=v_name,
            serial_number=nullif(p_operational->>'serial_number',''),
            acquisition_date=(p_operational->>'acquisition_date')::date,
            in_service_date=nullif(p_operational->>'in_service_date','')::date,
            acquisition_cost=case when v_has_depreciation then v_asset.acquisition_cost else coalesce(nullif(p_operational->>'acquisition_cost','')::numeric,0) end,
            residual_value=case when v_has_depreciation then v_asset.residual_value else coalesce(nullif(p_operational->>'residual_value','')::numeric,0) end,
            useful_life_months=case when v_has_depreciation then v_asset.useful_life_months else (p_operational->>'useful_life_months')::integer end,
            depreciation_method=case when v_has_depreciation then v_asset.depreciation_method else coalesce(nullif(p_operational->>'depreciation_method',''),'straight_line') end,
            accumulated_depreciation=case when v_has_depreciation then v_asset.accumulated_depreciation else coalesce(nullif(p_operational->>'accumulated_depreciation','')::numeric,0) end,
            net_book_value=case when v_has_depreciation then v_asset.net_book_value
              else greatest(coalesce(nullif(p_operational->>'acquisition_cost','')::numeric,0)-coalesce(nullif(p_operational->>'accumulated_depreciation','')::numeric,0),0) end,
            location=nullif(p_operational->>'location',''),
            custodian=nullif(p_operational->>'custodian',''),
            supplier_name=nullif(p_operational->>'supplier_name',''),
            purchase_reference=nullif(p_operational->>'purchase_reference',''),
            asset_account_id=nullif(p_operational->>'asset_account_id','')::uuid,
            accumulated_account_id=nullif(p_operational->>'accumulated_account_id','')::uuid,
            expense_account_id=nullif(p_operational->>'expense_account_id','')::uuid,
            status=coalesce(nullif(p_operational->>'status',''),'draft'),
            updated_at=now()
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'تعذر تحديث الأصل داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_fixed_assets(
          company_id,category_id,asset_code,name,serial_number,acquisition_date,in_service_date,
          acquisition_cost,residual_value,useful_life_months,depreciation_method,accumulated_depreciation,
          net_book_value,location,custodian,supplier_name,purchase_reference,
          asset_account_id,accumulated_account_id,expense_account_id,status
        ) values(
          v_company_id,v_item_id,coalesce(nullif(p_operational->>'asset_code',''),v_record_code),
          v_name,nullif(p_operational->>'serial_number',''),
          (p_operational->>'acquisition_date')::date,
          nullif(p_operational->>'in_service_date','')::date,
          coalesce(nullif(p_operational->>'acquisition_cost','')::numeric,0),
          coalesce(nullif(p_operational->>'residual_value','')::numeric,0),
          (p_operational->>'useful_life_months')::integer,
          coalesce(nullif(p_operational->>'depreciation_method',''),'straight_line'),
          coalesce(nullif(p_operational->>'accumulated_depreciation','')::numeric,0),
          greatest(coalesce(nullif(p_operational->>'acquisition_cost','')::numeric,0)-coalesce(nullif(p_operational->>'accumulated_depreciation','')::numeric,0),0),
          nullif(p_operational->>'location',''),nullif(p_operational->>'custodian',''),
          nullif(p_operational->>'supplier_name',''),nullif(p_operational->>'purchase_reference',''),
          nullif(p_operational->>'asset_account_id','')::uuid,
          nullif(p_operational->>'accumulated_account_id','')::uuid,
          nullif(p_operational->>'expense_account_id','')::uuid,
          coalesce(nullif(p_operational->>'status',''),'draft')
        )
        on conflict(company_id,asset_code) do nothing
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then
          raise exception 'يوجد أصل بهذا الكود بالفعل دون رابط سجل عام مطابق؛ افتح الأصل الحالي لتعديله بدل إنشاء أصل جديد' using errcode='23505';
        end if;
      end if;

    when v_module_key='manufacturing' and v_record_type='production_quality_check' then
      v_operational_table:='erp_production_quality_checks';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط فحص الجودة غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      select o.id into v_order_id
      from public.erp_production_orders o
      where o.id=nullif(p_operational->>'production_order_id','')::uuid
        and o.company_id=v_company_id
      for share;
      if not found then raise exception 'أمر التصنيع المرتبط بفحص الجودة غير موجود داخل الشركة' using errcode='23503'; end if;
      if coalesce(nullif(p_operational->>'result',''),'') not in ('pass','conditional','fail')
         or coalesce(nullif(p_operational->>'inspected_quantity','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'rejected_quantity','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'rejected_quantity','')::numeric,0)>
              coalesce(nullif(p_operational->>'inspected_quantity','')::numeric,0)
         or (nullif(p_operational->>'minimum_value','') is not null
             and nullif(p_operational->>'maximum_value','') is not null
             and (p_operational->>'minimum_value')::numeric>(p_operational->>'maximum_value')::numeric) then
        raise exception 'نتيجة فحص الجودة أو الكميات أو الحدود غير صالحة' using errcode='22023';
      end if;
      if v_operational_id is not null then
        update public.erp_production_quality_checks
        set inspection_code=coalesce(nullif(p_operational->>'inspection_code',''),v_record_code),
            production_order_id=v_order_id,
            inspection_stage=coalesce(nullif(p_operational->>'inspection_stage',''),'final'),
            parameter_name=coalesce(nullif(p_operational->>'parameter_name',''),v_name),
            measured_value=nullif(p_operational->>'measured_value','')::numeric,
            minimum_value=nullif(p_operational->>'minimum_value','')::numeric,
            maximum_value=nullif(p_operational->>'maximum_value','')::numeric,
            result=p_operational->>'result',
            inspected_quantity=coalesce(nullif(p_operational->>'inspected_quantity','')::numeric,0),
            rejected_quantity=coalesce(nullif(p_operational->>'rejected_quantity','')::numeric,0),
            inspector=nullif(p_operational->>'inspector',''),
            notes=nullif(p_operational->>'notes','')
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'فحص الجودة المرتبط غير موجود داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_production_quality_checks(
          company_id,production_order_id,inspection_code,inspection_stage,parameter_name,
          measured_value,minimum_value,maximum_value,result,inspected_quantity,rejected_quantity,inspector,notes
        ) values(
          v_company_id,v_order_id,coalesce(nullif(p_operational->>'inspection_code',''),v_record_code),
          coalesce(nullif(p_operational->>'inspection_stage',''),'final'),
          coalesce(nullif(p_operational->>'parameter_name',''),v_name),
          nullif(p_operational->>'measured_value','')::numeric,
          nullif(p_operational->>'minimum_value','')::numeric,
          nullif(p_operational->>'maximum_value','')::numeric,
          p_operational->>'result',
          coalesce(nullif(p_operational->>'inspected_quantity','')::numeric,0),
          coalesce(nullif(p_operational->>'rejected_quantity','')::numeric,0),
          nullif(p_operational->>'inspector',''),nullif(p_operational->>'notes','')
        )
        on conflict(company_id,inspection_code) do update
        set production_order_id=excluded.production_order_id,inspection_stage=excluded.inspection_stage,
            parameter_name=excluded.parameter_name,measured_value=excluded.measured_value,
            minimum_value=excluded.minimum_value,maximum_value=excluded.maximum_value,
            result=excluded.result,inspected_quantity=excluded.inspected_quantity,
            rejected_quantity=excluded.rejected_quantity,inspector=excluded.inspector,notes=excluded.notes,
            inspected_at=now()
        returning id into v_operational_id;
      end if;

    when v_module_key='manufacturing' and v_record_type='production_variance' then
      v_operational_table:='erp_production_variances';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط فرق الإنتاج غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      select o.id into v_order_id
      from public.erp_production_orders o
      where o.id=nullif(p_operational->>'production_order_id','')::uuid
        and o.company_id=v_company_id
      for share;
      if not found then raise exception 'أمر التصنيع المرتبط بفرق الإنتاج غير موجود داخل الشركة' using errcode='23503'; end if;
      v_item_id:=nullif(p_operational->>'item_id','')::uuid;
      if v_item_id is not null and not exists(
        select 1 from public.erp_items i where i.id=v_item_id and i.company_id=v_company_id
      ) then
        raise exception 'صنف فرق الإنتاج لا يتبع الشركة المحددة' using errcode='23503';
      end if;
      if coalesce(nullif(p_operational->>'variance_type',''),'') not in ('scrap','byproduct','disassembly','rework')
         or coalesce(nullif(p_operational->>'quantity','')::numeric,0)<=0
         or coalesce(nullif(p_operational->>'unit_cost','')::numeric,0)<0
         or nullif(btrim(p_operational->>'unit'),'') is null
         or nullif(btrim(p_operational->>'item_name'),'') is null then
        raise exception 'نوع فرق الإنتاج أو كميته أو وحدته أو تكلفته غير صالح' using errcode='22023';
      end if;
      v_amount:=coalesce(nullif(p_operational->>'amount','')::numeric,
        coalesce(nullif(p_operational->>'quantity','')::numeric,0)*coalesce(nullif(p_operational->>'unit_cost','')::numeric,0));
      if v_amount<0 then raise exception 'قيمة فرق الإنتاج لا يمكن أن تكون سالبة' using errcode='22023'; end if;
      if v_operational_id is not null then
        update public.erp_production_variances
        set variance_code=coalesce(nullif(p_operational->>'variance_code',''),v_record_code),
            production_order_id=v_order_id,item_id=v_item_id,
            item_name=p_operational->>'item_name',variance_type=p_operational->>'variance_type',
            quantity=(p_operational->>'quantity')::numeric,unit=p_operational->>'unit',
            unit_cost=coalesce(nullif(p_operational->>'unit_cost','')::numeric,0),amount=v_amount,
            reason=nullif(p_operational->>'reason',''),movement_date=(p_operational->>'movement_date')::date
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'فرق الإنتاج المرتبط غير موجود داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_production_variances(
          company_id,variance_code,production_order_id,item_id,item_name,variance_type,
          quantity,unit,unit_cost,amount,reason,movement_date
        ) values(
          v_company_id,coalesce(nullif(p_operational->>'variance_code',''),v_record_code),
          v_order_id,v_item_id,p_operational->>'item_name',p_operational->>'variance_type',
          (p_operational->>'quantity')::numeric,p_operational->>'unit',
          coalesce(nullif(p_operational->>'unit_cost','')::numeric,0),v_amount,
          nullif(p_operational->>'reason',''),(p_operational->>'movement_date')::date
        )
        on conflict(company_id,variance_code) do update
        set production_order_id=excluded.production_order_id,item_id=excluded.item_id,
            item_name=excluded.item_name,variance_type=excluded.variance_type,
            quantity=excluded.quantity,unit=excluded.unit,unit_cost=excluded.unit_cost,
            amount=excluded.amount,reason=excluded.reason,movement_date=excluded.movement_date
        returning id into v_operational_id;
      end if;

    when v_module_key='contracting' and v_record_type='project' then
      v_operational_table:='erp_construction_projects';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط المشروع غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      if not public.erp_user_has_company_role(v_company_id,array['owner','admin','manager']::text[]) then
        raise exception 'إنشاء المشروعات وتعديلها يتطلب مالكًا أو مديرًا إداريًا أو مدير الشركة' using errcode='42501';
      end if;
      v_party_id:=nullif(p_operational->>'customer_id','')::uuid;
      if v_party_id is not null and not exists(
        select 1 from public.erp_parties p where p.id=v_party_id and p.company_id=v_company_id
      ) then
        raise exception 'عميل المشروع لا يتبع الشركة المحددة' using errcode='23503';
      end if;
      if coalesce(nullif(p_operational->>'contract_value','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'budget_amount','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'retention_percent','')::numeric,0)<0
         or coalesce(nullif(p_operational->>'retention_percent','')::numeric,0)>100
         or coalesce(nullif(p_operational->>'status',''),'draft') not in ('draft','tender','awarded','in_progress','suspended','completed','closed','cancelled')
         or (nullif(p_operational->>'planned_start','') is not null
             and nullif(p_operational->>'planned_end','') is not null
             and (p_operational->>'planned_end')::date<(p_operational->>'planned_start')::date) then
        raise exception 'قيمة العقد أو الميزانية أو الاحتجاز أو حالة المشروع أو تواريخه غير صالحة' using errcode='22023';
      end if;
      if v_operational_id is not null then
        if not public.erp_user_can_access_project_scope(v_company_id,v_operational_id) then
          raise exception 'لا تملك صلاحية الوصول إلى هذا المشروع' using errcode='42501';
        end if;
        perform 1 from public.erp_construction_projects p
        where p.id=v_operational_id and p.company_id=v_company_id
        for update;
        if not found then raise exception 'المشروع المرتبط غير موجود داخل الشركة' using errcode='P0002'; end if;
        update public.erp_construction_projects
        set project_code=coalesce(nullif(p_operational->>'project_code',''),v_record_code),
            name=v_name,customer_id=v_party_id,
            site_address=nullif(p_operational->>'site_address',''),
            project_type=nullif(p_operational->>'project_type',''),
            contract_number=nullif(p_operational->>'contract_number',''),
            contract_value=coalesce(nullif(p_operational->>'contract_value','')::numeric,0),
            budget_amount=coalesce(nullif(p_operational->>'budget_amount','')::numeric,0),
            planned_start=nullif(p_operational->>'planned_start','')::date,
            planned_end=nullif(p_operational->>'planned_end','')::date,
            status=coalesce(nullif(p_operational->>'status',''),'draft'),
            project_manager=nullif(p_operational->>'project_manager',''),
            retention_percent=coalesce(nullif(p_operational->>'retention_percent','')::numeric,0),
            notes=nullif(p_operational->>'notes',''),
            updated_at=now()
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'تعذر تحديث المشروع داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_construction_projects(
          company_id,project_code,name,customer_id,site_address,project_type,contract_number,
          contract_value,budget_amount,planned_start,planned_end,status,project_manager,
          retention_percent,notes
        ) values(
          v_company_id,coalesce(nullif(p_operational->>'project_code',''),v_record_code),
          v_name,v_party_id,nullif(p_operational->>'site_address',''),
          nullif(p_operational->>'project_type',''),nullif(p_operational->>'contract_number',''),
          coalesce(nullif(p_operational->>'contract_value','')::numeric,0),
          coalesce(nullif(p_operational->>'budget_amount','')::numeric,0),
          nullif(p_operational->>'planned_start','')::date,
          nullif(p_operational->>'planned_end','')::date,
          coalesce(nullif(p_operational->>'status',''),'draft'),
          nullif(p_operational->>'project_manager',''),
          coalesce(nullif(p_operational->>'retention_percent','')::numeric,0),
          nullif(p_operational->>'notes','')
        )
        on conflict(company_id,project_code) do update
        set name=excluded.name,customer_id=excluded.customer_id,site_address=excluded.site_address,
            project_type=excluded.project_type,contract_number=excluded.contract_number,
            contract_value=excluded.contract_value,budget_amount=excluded.budget_amount,
            planned_start=excluded.planned_start,planned_end=excluded.planned_end,
            status=excluded.status,project_manager=excluded.project_manager,
            retention_percent=excluded.retention_percent,notes=excluded.notes,updated_at=now()
        returning id into v_operational_id;
      end if;

    when v_module_key='contracting' and v_record_type='site_report' then
      v_operational_table:='erp_construction_site_reports';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط تقرير الموقع غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      v_project_id:=nullif(p_operational->>'project_id','')::uuid;
      if v_project_id is null or not exists(
        select 1 from public.erp_construction_projects p
        where p.id=v_project_id and p.company_id=v_company_id
      ) then
        raise exception 'مشروع تقرير الموقع غير موجود داخل الشركة' using errcode='23503';
      end if;
      if not public.erp_user_can_access_project_scope(v_company_id,v_project_id) then
        raise exception 'لا تملك صلاحية الوصول إلى مشروع تقرير الموقع' using errcode='42501';
      end if;
      if coalesce(nullif(p_operational->>'labor_count','')::integer,0)<0
         or coalesce(nullif(p_operational->>'status',''),'draft') not in ('draft','submitted','approved','rejected') then
        raise exception 'عدد العمال أو حالة تقرير الموقع غير صالحة' using errcode='22023';
      end if;
      if v_operational_id is not null then
        update public.erp_construction_site_reports
        set report_code=coalesce(nullif(p_operational->>'report_code',''),v_record_code),
            project_id=v_project_id,report_date=(p_operational->>'report_date')::date,
            engineer=nullif(p_operational->>'engineer',''),
            weather=nullif(p_operational->>'weather',''),
            labor_count=coalesce(nullif(p_operational->>'labor_count','')::integer,0),
            equipment=nullif(p_operational->>'equipment',''),
            materials=nullif(p_operational->>'materials',''),
            work_done=nullif(p_operational->>'work_done',''),
            issues=nullif(p_operational->>'issues',''),
            safety=nullif(p_operational->>'safety',''),
            status=coalesce(nullif(p_operational->>'status',''),'draft')
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'تقرير الموقع المرتبط غير موجود داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_construction_site_reports(
          company_id,project_id,report_code,report_date,engineer,weather,labor_count,
          equipment,materials,work_done,issues,safety,status
        ) values(
          v_company_id,v_project_id,coalesce(nullif(p_operational->>'report_code',''),v_record_code),
          (p_operational->>'report_date')::date,nullif(p_operational->>'engineer',''),
          nullif(p_operational->>'weather',''),coalesce(nullif(p_operational->>'labor_count','')::integer,0),
          nullif(p_operational->>'equipment',''),nullif(p_operational->>'materials',''),
          nullif(p_operational->>'work_done',''),nullif(p_operational->>'issues',''),
          nullif(p_operational->>'safety',''),coalesce(nullif(p_operational->>'status',''),'draft')
        )
        on conflict(company_id,report_code) do update
        set project_id=excluded.project_id,report_date=excluded.report_date,engineer=excluded.engineer,
            weather=excluded.weather,labor_count=excluded.labor_count,equipment=excluded.equipment,
            materials=excluded.materials,work_done=excluded.work_done,issues=excluded.issues,
            safety=excluded.safety,status=excluded.status
        returning id into v_operational_id;
      end if;

    when v_module_key='customer_service' and v_record_type='ticket' then
      v_operational_table:='erp_service_tickets';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط تذكرة خدمة العملاء غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      v_party_id:=nullif(p_operational->>'party_id','')::uuid;
      if v_party_id is not null and not exists(
        select 1 from public.erp_parties p where p.id=v_party_id and p.company_id=v_company_id
      ) then
        raise exception 'العميل المرتبط بالتذكرة لا يتبع الشركة المحددة' using errcode='23503';
      end if;
      v_ticket_id:=nullif(p_operational->>'sla_policy_id','')::uuid;
      if v_ticket_id is not null and not exists(
        select 1 from public.erp_service_sla_policies p where p.id=v_ticket_id and p.company_id=v_company_id
      ) then
        raise exception 'سياسة SLA المرتبطة بالتذكرة لا تتبع الشركة المحددة' using errcode='23503';
      end if;
      if coalesce(nullif(p_operational->>'priority',''),'normal') not in ('low','normal','high','urgent')
         or coalesce(nullif(p_operational->>'status',''),'open') not in ('open','assigned','in_progress','waiting_customer','resolved','closed','cancelled')
         or (nullif(p_operational->>'satisfaction_score','') is not null and ((p_operational->>'satisfaction_score')::numeric<0 or (p_operational->>'satisfaction_score')::numeric>5)) then
        raise exception 'أولوية التذكرة أو حالتها أو تقييم رضا العميل غير صالح' using errcode='22023';
      end if;
      if v_operational_id is not null then
        update public.erp_service_tickets
        set ticket_code=coalesce(nullif(p_operational->>'ticket_code',''),v_record_code),
            subject=v_name,
            description=nullif(p_operational->>'description',''),
            party_id=v_party_id,
            channel=coalesce(nullif(p_operational->>'channel',''),'other'),
            category=coalesce(nullif(p_operational->>'category',''),'general'),
            priority=coalesce(nullif(p_operational->>'priority',''),'normal'),
            status=coalesce(nullif(p_operational->>'status',''),'open'),
            team_name=nullif(p_operational->>'team_name',''),
            sla_policy_id=v_ticket_id,
            first_response_due_at=nullif(p_operational->>'first_response_due_at','')::timestamptz,
            resolution_due_at=nullif(p_operational->>'resolution_due_at','')::timestamptz,
            escalation_due_at=nullif(p_operational->>'escalation_due_at','')::timestamptz,
            first_responded_at=case
              when coalesce(nullif(p_operational->>'status',''),'open') in ('in_progress','resolved','closed')
                then coalesce(first_responded_at,nullif(p_operational->>'first_responded_at','')::timestamptz)
              else first_responded_at
            end,
            resolved_at=case
              when coalesce(nullif(p_operational->>'status',''),'open')='resolved'
                then coalesce(resolved_at,nullif(p_operational->>'resolved_at','')::timestamptz)
              else null
            end,
            closed_at=case
              when coalesce(nullif(p_operational->>'status',''),'open')='closed'
                then coalesce(closed_at,nullif(p_operational->>'closed_at','')::timestamptz)
              else null
            end,
            resolution=nullif(p_operational->>'resolution',''),
            satisfaction_score=nullif(p_operational->>'satisfaction_score','')::numeric,
            updated_at=now()
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'التذكرة المرتبطة غير موجودة داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_service_tickets(
          company_id,ticket_code,subject,description,party_id,channel,category,priority,status,
          team_name,sla_policy_id,first_response_due_at,resolution_due_at,escalation_due_at,
          first_responded_at,resolved_at,closed_at,resolution,satisfaction_score
        ) values(
          v_company_id,coalesce(nullif(p_operational->>'ticket_code',''),v_record_code),
          v_name,nullif(p_operational->>'description',''),v_party_id,
          coalesce(nullif(p_operational->>'channel',''),'other'),
          coalesce(nullif(p_operational->>'category',''),'general'),
          coalesce(nullif(p_operational->>'priority',''),'normal'),
          coalesce(nullif(p_operational->>'status',''),'open'),
          nullif(p_operational->>'team_name',''),v_ticket_id,
          nullif(p_operational->>'first_response_due_at','')::timestamptz,
          nullif(p_operational->>'resolution_due_at','')::timestamptz,
          nullif(p_operational->>'escalation_due_at','')::timestamptz,
          nullif(p_operational->>'first_responded_at','')::timestamptz,
          nullif(p_operational->>'resolved_at','')::timestamptz,
          nullif(p_operational->>'closed_at','')::timestamptz,
          nullif(p_operational->>'resolution',''),
          nullif(p_operational->>'satisfaction_score','')::numeric
        )
        on conflict(company_id,ticket_code) do update
        set subject=excluded.subject,description=excluded.description,party_id=excluded.party_id,
            channel=excluded.channel,category=excluded.category,priority=excluded.priority,
            status=excluded.status,team_name=excluded.team_name,sla_policy_id=excluded.sla_policy_id,
            first_response_due_at=excluded.first_response_due_at,
            resolution_due_at=excluded.resolution_due_at,escalation_due_at=excluded.escalation_due_at,
            first_responded_at=coalesce(public.erp_service_tickets.first_responded_at,excluded.first_responded_at),
            resolved_at=excluded.resolved_at,closed_at=excluded.closed_at,
            resolution=excluded.resolution,satisfaction_score=excluded.satisfaction_score,updated_at=now()
        returning id into v_operational_id;
      end if;

    when v_module_key='customer_service' and v_record_type='field_task' then
      v_operational_table:='erp_service_visits';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط الزيارة الميدانية غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      v_ticket_id:=nullif(p_operational->>'ticket_id','')::uuid;
      if v_ticket_id is not null and not exists(
        select 1 from public.erp_service_tickets t where t.id=v_ticket_id and t.company_id=v_company_id
      ) then
        raise exception 'التذكرة المرتبطة بالزيارة لا تتبع الشركة المحددة' using errcode='23503';
      end if;
      if coalesce(nullif(p_operational->>'status',''),'planned') not in ('planned','confirmed','in_progress','completed','cancelled','missed')
         or coalesce(nullif(p_operational->>'labor_minutes','')::integer,0)<0
         or jsonb_typeof(coalesce(p_operational->'materials','[]'::jsonb))<>'array' then
        raise exception 'حالة الزيارة أو زمن العمل أو قائمة المواد غير صالحة' using errcode='22023';
      end if;
      if v_operational_id is not null then
        update public.erp_service_visits
        set visit_code=coalesce(nullif(p_operational->>'visit_code',''),v_record_code),
            ticket_id=v_ticket_id,
            scheduled_at=(p_operational->>'scheduled_at')::timestamptz,
            address=nullif(p_operational->>'address',''),
            visit_type=coalesce(nullif(p_operational->>'visit_type',''),'service'),
            status=coalesce(nullif(p_operational->>'status',''),'planned'),
            labor_minutes=coalesce(nullif(p_operational->>'labor_minutes','')::integer,0),
            materials=coalesce(p_operational->'materials','[]'::jsonb),
            outcome=nullif(p_operational->>'outcome',''),
            customer_signature_reference=nullif(p_operational->>'customer_signature_reference',''),
            updated_at=now()
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'الزيارة الميدانية المرتبطة غير موجودة داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_service_visits(
          company_id,visit_code,ticket_id,scheduled_at,address,visit_type,status,
          labor_minutes,materials,outcome,customer_signature_reference
        ) values(
          v_company_id,coalesce(nullif(p_operational->>'visit_code',''),v_record_code),v_ticket_id,
          (p_operational->>'scheduled_at')::timestamptz,
          nullif(p_operational->>'address',''),
          coalesce(nullif(p_operational->>'visit_type',''),'service'),
          coalesce(nullif(p_operational->>'status',''),'planned'),
          coalesce(nullif(p_operational->>'labor_minutes','')::integer,0),
          coalesce(p_operational->'materials','[]'::jsonb),
          nullif(p_operational->>'outcome',''),
          nullif(p_operational->>'customer_signature_reference','')
        )
        on conflict(company_id,visit_code) do update
        set ticket_id=excluded.ticket_id,scheduled_at=excluded.scheduled_at,address=excluded.address,
            visit_type=excluded.visit_type,status=excluded.status,labor_minutes=excluded.labor_minutes,
            materials=excluded.materials,outcome=excluded.outcome,
            customer_signature_reference=excluded.customer_signature_reference,updated_at=now()
        returning id into v_operational_id;
      end if;

    when v_module_key='customer_service' and v_record_type='activity' then
      v_operational_table:='erp_crm_activities';
      if v_operational_id is not null and v_old_operational_table is distinct from v_operational_table then
        raise exception 'رابط نشاط CRM غير متطابق؛ أوقف التعديل للمراجعة' using errcode='23514';
      end if;
      v_ticket_id:=nullif(p_operational->>'ticket_id','')::uuid;
      v_lead_id:=nullif(p_operational->>'lead_id','')::uuid;
      if v_ticket_id is not null and not exists(select 1 from public.erp_service_tickets t where t.id=v_ticket_id and t.company_id=v_company_id) then
        raise exception 'التذكرة المرتبطة بالنشاط لا تتبع الشركة المحددة' using errcode='23503';
      end if;
      if v_lead_id is not null and not exists(select 1 from public.erp_crm_leads l where l.id=v_lead_id and l.company_id=v_company_id) then
        raise exception 'الفرصة المرتبطة بالنشاط لا تتبع الشركة المحددة' using errcode='23503';
      end if;
      if coalesce(nullif(p_operational->>'activity_type',''),'task') not in ('call','email','whatsapp','meeting','visit','task','reminder')
         or coalesce(nullif(p_operational->>'status',''),'planned') not in ('planned','done','cancelled') then
        raise exception 'نوع النشاط أو حالته غير صالح' using errcode='22023';
      end if;
      if v_operational_id is not null then
        update public.erp_crm_activities
        set activity_code=coalesce(nullif(p_operational->>'activity_code',''),v_record_code),
            activity_type=coalesce(nullif(p_operational->>'activity_type',''),'task'),
            subject=v_name,ticket_id=v_ticket_id,lead_id=v_lead_id,
            scheduled_at=nullif(p_operational->>'scheduled_at','')::timestamptz,
            outcome=nullif(p_operational->>'outcome',''),
            next_step=nullif(p_operational->>'next_step',''),
            status=coalesce(nullif(p_operational->>'status',''),'planned')
        where id=v_operational_id and company_id=v_company_id
        returning id into v_operational_id;
        get diagnostics v_count=row_count;
        if v_count<>1 then raise exception 'نشاط CRM المرتبط غير موجود داخل الشركة' using errcode='P0002'; end if;
      else
        insert into public.erp_crm_activities(
          company_id,activity_code,activity_type,subject,ticket_id,lead_id,
          scheduled_at,outcome,next_step,status
        ) values(
          v_company_id,coalesce(nullif(p_operational->>'activity_code',''),v_record_code),
          coalesce(nullif(p_operational->>'activity_type',''),'task'),v_name,
          v_ticket_id,v_lead_id,
          nullif(p_operational->>'scheduled_at','')::timestamptz,
          nullif(p_operational->>'outcome',''),nullif(p_operational->>'next_step',''),
          coalesce(nullif(p_operational->>'status',''),'planned')
        )
        on conflict(company_id,activity_code) do update
        set activity_type=excluded.activity_type,subject=excluded.subject,
            ticket_id=excluded.ticket_id,lead_id=excluded.lead_id,
            scheduled_at=excluded.scheduled_at,outcome=excluded.outcome,
            next_step=excluded.next_step,status=excluded.status
        returning id into v_operational_id;
      end if;
  end case;

  if v_operational_id is null then
    raise exception 'تعذر حفظ السجل التشغيلي المرتبط' using errcode='P0002';
  end if;

  v_details:= (v_details - '_operational_table' - '_operational_id')
    || jsonb_build_object(
      '_operational_table',v_operational_table,
      '_operational_id',v_operational_id
    );

  if p_parent_record_id is null then
    insert into public.erp_business_suite_records(
      company_id,module_key,record_type,record_code,name,status,
      record_date,due_date,counterparty,amount,quantity,details,created_by
    ) values(
      v_company_id,v_module_key,v_record_type,v_record_code,v_name,v_status,
      v_record_date,v_due_date,v_counterparty,v_amount,v_quantity,v_details,v_user_id
    )
    returning id into v_parent_id;
  else
    update public.erp_business_suite_records
    set record_code=v_record_code,name=v_name,status=v_status,
        record_date=v_record_date,due_date=v_due_date,counterparty=v_counterparty,
        amount=v_amount,quantity=v_quantity,details=v_details,updated_at=now()
    where id=p_parent_record_id and company_id=v_company_id
      and module_key=v_module_key and record_type=v_record_type
    returning id into v_parent_id;
    if v_parent_id is null then
      raise exception 'تعذر تحديث السجل العام أو لا تملك صلاحية تعديله' using errcode='42501';
    end if;
  end if;

  return v_details;
end;
$function$
;

revoke all on function public.erp_save_business_suite_simple_record_atomic(uuid,jsonb,jsonb) from public;
revoke all on function public.erp_save_business_suite_simple_record_atomic(uuid,jsonb,jsonb) from anon;
grant execute on function public.erp_save_business_suite_simple_record_atomic(uuid,jsonb,jsonb) to authenticated;
