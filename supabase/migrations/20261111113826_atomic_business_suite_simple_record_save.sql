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
    ('customer_service','field_task'),
    ('customer_service','activity')
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
        set category_code=nullif(p_operational->>'category_code',''),
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
          v_company_id,nullif(p_operational->>'category_code',''),v_name,
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
        set center_code=nullif(p_operational->>'center_code',''),
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
          v_company_id,nullif(p_operational->>'center_code',''),v_name,
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
        set lead_code=nullif(p_operational->>'lead_code',''),
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
          v_company_id,nullif(p_operational->>'lead_code',''),v_name,v_party_id,
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
        set policy_code=nullif(p_operational->>'policy_code',''),
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
          v_company_id,nullif(p_operational->>'policy_code',''),v_name,
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
        set visit_code=nullif(p_operational->>'visit_code',''),
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
          v_company_id,nullif(p_operational->>'visit_code',''),v_ticket_id,
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
        set activity_code=nullif(p_operational->>'activity_code',''),
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
          v_company_id,nullif(p_operational->>'activity_code',''),
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
