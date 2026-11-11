CREATE OR REPLACE FUNCTION public.erp_post_operational_document_accounting(p_document_id uuid, p_kind text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_company_id uuid;
  v_branch_id uuid;
  v_warehouse_id uuid;
  v_warehouse_branch_id uuid;
  v_party_id uuid;
  v_doc_date date;
  v_doc_number text;
  v_doc_type text;
  v_status text;
  v_subtotal numeric(14,2);
  v_discount numeric(14,2);
  v_tax numeric(14,2);
  v_total numeric(14,2);
  v_cost numeric(14,2);
  v_line_count bigint;
  v_movement_count bigint;
  v_net numeric(14,2);
  v_variance numeric(14,2);
  v_mapping public.erp_operational_account_mappings%rowtype;
  v_entry_id uuid;
  v_source_type text;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_account_id uuid;
  v_debit numeric(14,2);
  v_credit numeric(14,2);
  v_description text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولًا'; end if;
  if p_kind not in ('purchase','sales') then raise exception 'نوع المستند غير مدعوم'; end if;

  if p_kind = 'purchase' then
    select company_id, branch_id, warehouse_id, supplier_id, document_date, document_number, document_type,
      status, subtotal, discount_total, tax_total, grand_total
    into v_company_id, v_branch_id, v_warehouse_id, v_party_id, v_doc_date, v_doc_number, v_doc_type,
      v_status, v_subtotal, v_discount, v_tax, v_total
    from public.erp_purchase_documents where id = p_document_id for update;
    v_source_type := 'purchase_accounting';
  else
    select company_id, branch_id, warehouse_id, customer_id, document_date, document_number, document_type,
      status, subtotal, discount_total, tax_total, grand_total
    into v_company_id, v_branch_id, v_warehouse_id, v_party_id, v_doc_date, v_doc_number, v_doc_type,
      v_status, v_subtotal, v_discount, v_tax, v_total
    from public.erp_sales_documents where id = p_document_id for update;
    v_source_type := 'sales_accounting';
  end if;

  if v_company_id is null then raise exception 'المستند غير موجود'; end if;
  if not public.erp_user_has_company_role(v_company_id, array['owner','admin','accountant']::text[]) then
    raise exception 'ترحيل الأثر المحاسبي يتطلب صلاحية محاسب أو مدير';
  end if;
  select w.branch_id into v_warehouse_branch_id
  from public.erp_warehouses w
  where w.id=v_warehouse_id and w.company_id=v_company_id and w.is_active;
  if not found then raise exception 'مخزن المستند غير نشط أو لا يتبع الشركة'; end if;
  if v_branch_id is not null and v_branch_id<>v_warehouse_branch_id then
    raise exception 'فرع المستند لا يطابق فرع المخزن';
  end if;
  if not public.erp_user_can_access_warehouse_scope(v_company_id,v_warehouse_branch_id,v_warehouse_id) then
    raise exception 'لا تملك صلاحية الوصول إلى مخزن المستند أو فرعه' using errcode='42501';
  end if;
  v_branch_id:=coalesce(v_branch_id,v_warehouse_branch_id);
  if v_status <> 'posted' then raise exception 'يجب ترحيل المستند المخزني أولًا'; end if;
  if p_kind = 'purchase' and v_doc_type not in ('receipt','invoice','return') then
    raise exception 'نوع مستند المشتريات لا ينشئ أثرًا محاسبيًا مخزنيًا';
  end if;
  if p_kind = 'sales' and v_doc_type not in ('delivery','invoice','return') then
    raise exception 'نوع مستند المبيعات لا ينشئ أثرًا محاسبيًا مخزنيًا';
  end if;

  select id into v_entry_id from public.erp_journal_entries
  where company_id = v_company_id and source_type = v_source_type and source_id = p_document_id
    and status = 'posted' limit 1;
  if v_entry_id is not null then return v_entry_id; end if;
  if exists (select 1 from public.erp_journal_entries
    where company_id = v_company_id and source_type = v_source_type and source_id = p_document_id) then
    raise exception 'يوجد قيد محاسبي مسودة مرتبط بالمستند؛ راجعه قبل إعادة المحاولة';
  end if;

  select * into v_mapping from public.erp_operational_account_mappings
  where company_id = v_company_id;
  if not found then raise exception 'يجب إعداد خريطة الحسابات التشغيلية للشركة أولًا'; end if;

  v_net := round(v_subtotal - v_discount, 2);
  if v_net < 0 or v_total <> round(v_net + v_tax, 2) then
    raise exception 'إجماليات المستند غير متوازنة؛ راجع الخصم والضريبة قبل الترحيل المحاسبي';
  end if;

  select coalesce(sum(
    case
      when p_kind = 'sales' and v_doc_type = 'return' and m.movement_type = 'customer_return'
        then m.quantity_in * m.unit_cost
      when p_kind = 'sales' and v_doc_type <> 'return' and m.movement_type = 'sales_issue'
        then m.quantity_out * m.unit_cost
      when p_kind = 'purchase' and v_doc_type = 'return' and m.movement_type = 'supplier_return'
        then m.quantity_out * m.unit_cost
      else 0
    end
  ),0)::numeric(14,2)
  into v_cost
  from public.erp_inventory_movements m
  where m.company_id = v_company_id
    and m.reference_id = p_document_id
    and m.reference_type = case when p_kind = 'purchase' then 'purchase_document' else 'sales_document' end;

  if p_kind = 'purchase' then
    select count(*) into v_line_count from public.erp_purchase_lines where document_id = p_document_id;
  else
    select count(*) into v_line_count from public.erp_sales_lines where document_id = p_document_id;
  end if;
  select count(*) into v_movement_count
  from public.erp_inventory_movements m
  where m.company_id = v_company_id
    and m.reference_id = p_document_id
    and m.reference_type = case when p_kind = 'purchase' then 'purchase_document' else 'sales_document' end
    and m.movement_type = case
      when p_kind = 'purchase' and v_doc_type = 'return' then 'supplier_return'
      when p_kind = 'purchase' then 'purchase_receipt'
      when p_kind = 'sales' and v_doc_type = 'return' then 'customer_return'
      else 'sales_issue'
    end;
  if v_line_count = 0 or v_movement_count <> v_line_count then
    raise exception 'حركات المخزون لا تطابق عدد بنود المستند؛ راجع المستند قبل الترحيل المحاسبي';
  end if;

  if p_kind = 'sales' then
    if v_doc_type = 'return' then
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.sales_returns_account_id,'debit',v_net,'credit',0,'description','مرتجع مبيعات ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.accounts_receivable_account_id,'debit',0,'credit',v_total,'description','تخفيض مديونية عميل - ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id)
      );
      if v_tax > 0 then
        if v_mapping.sales_tax_payable_account_id is null then raise exception 'حدد حساب ضريبة المبيعات قبل ترحيل هذا المستند'; end if;
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.sales_tax_payable_account_id,'debit',v_tax,'credit',0,'description','عكس ضريبة مبيعات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
      if v_cost > 0 then
        v_lines := v_lines || jsonb_build_array(
          jsonb_build_object('account_id',v_mapping.inventory_account_id,'debit',v_cost,'credit',0,'description','إعادة مخزون مرتجع مبيعات ' || v_doc_number,'branch_id',v_branch_id),
          jsonb_build_object('account_id',v_mapping.cost_of_goods_sold_account_id,'debit',0,'credit',v_cost,'description','عكس تكلفة بضاعة مرتجعة ' || v_doc_number,'branch_id',v_branch_id)
        );
      end if;
    else
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.accounts_receivable_account_id,'debit',v_total,'credit',0,'description','مبيعات ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.sales_revenue_account_id,'debit',0,'credit',v_net,'description','إيراد مبيعات ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id)
      );
      if v_tax > 0 then
        if v_mapping.sales_tax_payable_account_id is null then raise exception 'حدد حساب ضريبة المبيعات قبل ترحيل هذا المستند'; end if;
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.sales_tax_payable_account_id,'debit',0,'credit',v_tax,'description','ضريبة مبيعات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.cost_of_goods_sold_account_id,'debit',v_cost,'credit',0,'description','تكلفة بضاعة مباعة ' || v_doc_number,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.inventory_account_id,'debit',0,'credit',v_cost,'description','تخفيض المخزون - ' || v_doc_number,'branch_id',v_branch_id)
      );
    end if;
  else
    if v_doc_type = 'return' then
      if v_tax > 0 and v_mapping.purchase_tax_credit_account_id is null then
        raise exception 'حدد حساب ضريبة المدخلات قبل ترحيل مرتجع المشتريات';
      end if;
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.accounts_payable_account_id,'debit',v_total,'credit',0,'description','مرتجع مشتريات ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.inventory_account_id,'debit',0,'credit',v_cost,'description','تخفيض مخزون مرتجع مشتريات ' || v_doc_number,'branch_id',v_branch_id)
      );
      if v_tax > 0 then
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.purchase_tax_credit_account_id,'debit',0,'credit',v_tax,'description','عكس ضريبة مشتريات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
      v_variance := round(v_total - v_tax - v_cost, 2);
      if v_variance > 0 then
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.purchase_return_variance_account_id,'debit',0,'credit',v_variance,'description','فرق تقييم مرتجع مشتريات ' || v_doc_number,'branch_id',v_branch_id));
      elsif v_variance < 0 then
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.purchase_return_variance_account_id,'debit',abs(v_variance),'credit',0,'description','فرق تقييم مرتجع مشتريات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
    else
      if v_tax > 0 and v_mapping.purchase_tax_credit_account_id is null then
        raise exception 'حدد حساب ضريبة المدخلات قبل ترحيل هذا المستند';
      end if;
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object('account_id',v_mapping.inventory_account_id,'debit',v_net,'credit',0,'description','مخزون مشتريات ' || v_doc_number,'branch_id',v_branch_id),
        jsonb_build_object('account_id',v_mapping.accounts_payable_account_id,'debit',0,'credit',v_total,'description','مستحق للمورد ' || v_doc_number,'party_id',v_party_id,'branch_id',v_branch_id)
      );
      if v_tax > 0 then
        v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id',v_mapping.purchase_tax_credit_account_id,'debit',v_tax,'credit',0,'description','ضريبة مدخلات ' || v_doc_number,'branch_id',v_branch_id));
      end if;
    end if;
  end if;

  insert into public.erp_journal_entries(
    company_id, branch_id, fiscal_period_id, entry_date, description,
    source_type, source_id, status, created_by
  ) values (
    v_company_id, v_branch_id,
    (select fp.id from public.erp_fiscal_periods fp where fp.company_id = v_company_id
      and v_doc_date between fp.starts_on and fp.ends_on order by fp.starts_on desc limit 1),
    v_doc_date, 'قيد آلي للمستند ' || v_doc_number, v_source_type, p_document_id, 'draft', auth.uid()
  ) returning id into v_entry_id;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    v_account_id := nullif(v_line->>'account_id','')::uuid;
    v_debit := coalesce(nullif(v_line->>'debit','')::numeric,0);
    v_credit := coalesce(nullif(v_line->>'credit','')::numeric,0);
    v_description := nullif(v_line->>'description','');
    if v_account_id is null or not ((v_debit > 0 and v_credit = 0) or (v_credit > 0 and v_debit = 0)) then
      if v_debit = 0 and v_credit = 0 then continue; end if;
      raise exception 'سطر قيد آلي غير صالح؛ راجع خريطة الحسابات وقيم المستند';
    end if;
    if not exists (select 1 from public.erp_accounts a where a.id = v_account_id and a.company_id = v_company_id and a.is_active and a.is_postable) then
      raise exception 'أحد حسابات الربط غير نشط أو لا يتبع الشركة أو غير قابل للترحيل';
    end if;
    insert into public.erp_journal_lines(entry_id, account_id, description, debit, credit, party_id, branch_id)
    values (v_entry_id, v_account_id, v_description, v_debit, v_credit,
      nullif(v_line->>'party_id','')::uuid, nullif(v_line->>'branch_id','')::uuid);
  end loop;

  perform public.erp_post_journal_entry(v_entry_id);
  return v_entry_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.erp_post_cash_voucher(p_voucher_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v public.erp_cash_vouchers%rowtype;
  v_source_account uuid;
  v_target_account uuid;
  v_source_branch_id uuid;
  v_target_branch_id uuid;
  v_journal_id uuid;
  v_lines jsonb;
begin
  select * into v from public.erp_cash_vouchers where id = p_voucher_id for update;
  if not found then raise exception 'سند الخزينة غير موجود'; end if;
  if not public.erp_user_has_company_role(v.company_id, array['owner','admin','accountant']::text[]) then
    raise exception 'ليست لديك صلاحية ترحيل سندات الخزائن';
  end if;
  if v.status <> 'draft' then raise exception 'يمكن ترحيل المسودات فقط'; end if;
  if v.amount <= 0 then raise exception 'قيمة السند يجب أن تكون أكبر من صفر'; end if;

  select c.account_id, c.branch_id into v_source_account, v_source_branch_id
  from public.erp_cashboxes c
  join public.erp_accounts a on a.id = c.account_id and a.company_id = c.company_id
  where c.id = v.source_cashbox_id and c.company_id = v.company_id
    and c.is_active and a.is_active and a.is_postable;
  if v_source_account is null or v_source_branch_id is null then
    raise exception 'حساب الخزينة المصدر غير صالح أو بلا فرع';
  end if;
  if v.branch_id is not null and v.branch_id<>v_source_branch_id then
    raise exception 'فرع السند لا يطابق فرع الخزينة المصدر';
  end if;
  if not public.erp_user_can_access_branch_scope(v.company_id,v_source_branch_id) then
    raise exception 'لا تملك صلاحية الوصول إلى فرع الخزينة المصدر' using errcode='42501';
  end if;
  v.branch_id:=v_source_branch_id;

  if v.voucher_type = 'transfer' then
    select c.account_id, c.branch_id into v_target_account, v_target_branch_id
    from public.erp_cashboxes c
    join public.erp_accounts a on a.id = c.account_id and a.company_id = c.company_id
    where c.id = v.destination_cashbox_id and c.company_id = v.company_id
      and c.is_active and a.is_active and a.is_postable;
    if v_target_account is null or v_target_account = v_source_account or v_target_branch_id is null then
      raise exception 'حسابا الخزينتين غير صالحين أو متطابقان أو بلا فرع';
    end if;
    if not public.erp_user_can_access_branch_scope(v.company_id,v_target_branch_id) then
      raise exception 'لا تملك صلاحية الوصول إلى فرع الخزينة المستقبلة' using errcode='42501';
    end if;
    v_lines := jsonb_build_array(
      jsonb_build_object('account_id', v_target_account, 'description', v.description, 'debit', v.amount, 'credit', 0, 'branch_id', v_target_branch_id),
      jsonb_build_object('account_id', v_source_account, 'description', v.description, 'debit', 0, 'credit', v.amount, 'branch_id', v_source_branch_id)
    );
  elsif v.voucher_type = 'receipt' then
    v_lines := jsonb_build_array(
      jsonb_build_object('account_id', v_source_account, 'description', v.description, 'debit', v.amount, 'credit', 0, 'branch_id', v.branch_id),
      jsonb_build_object('account_id', v.counter_account_id, 'description', v.description, 'debit', 0, 'credit', v.amount, 'party_id', v.party_id, 'branch_id', v.branch_id)
    );
  elsif v.voucher_type = 'payment' then
    v_lines := jsonb_build_array(
      jsonb_build_object('account_id', v.counter_account_id, 'description', v.description, 'debit', v.amount, 'credit', 0, 'party_id', v.party_id, 'branch_id', v.branch_id),
      jsonb_build_object('account_id', v_source_account, 'description', v.description, 'debit', 0, 'credit', v.amount, 'branch_id', v.branch_id)
    );
  else
    raise exception 'نوع سند الخزينة غير مدعوم';
  end if;

  v_journal_id := public.erp_save_journal_draft(
    v.company_id, v.voucher_date, v.description, v_lines, null
  );
  update public.erp_journal_entries
  set branch_id=v_source_branch_id,updated_at=now()
  where id=v_journal_id and company_id=v.company_id;
  perform public.erp_post_journal_entry(v_journal_id);

  update public.erp_cash_vouchers
     set status = 'posted', branch_id = v_source_branch_id, journal_entry_id = v_journal_id,
         posted_by = auth.uid(), posted_at = now(), updated_at = now()
   where id = v.id;

  return v_journal_id;
end;
$function$
;
revoke all on function public.erp_post_operational_document_accounting(uuid,text) from public;
revoke all on function public.erp_post_operational_document_accounting(uuid,text) from anon;
grant execute on function public.erp_post_operational_document_accounting(uuid,text) to authenticated;

revoke all on function public.erp_post_cash_voucher(uuid) from public;
revoke all on function public.erp_post_cash_voucher(uuid) from anon;
grant execute on function public.erp_post_cash_voucher(uuid) to authenticated;
