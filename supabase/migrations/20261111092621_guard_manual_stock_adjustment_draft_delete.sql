CREATE OR REPLACE FUNCTION public.erp_delete_manual_stock_adjustment_draft(p_stocktake_id uuid, p_company_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_doc public.erp_stocktakes%rowtype;
  v_warehouse_branch uuid;
  v_deleted uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'يلزم تسجيل الدخول' using errcode='28000';
  end if;
  if p_stocktake_id is null or p_company_id is null then
    raise exception 'معرف المسودة والشركة مطلوبان' using errcode='22023';
  end if;

  select s.* into v_doc
  from public.erp_stocktakes s
  where s.id=p_stocktake_id
    and s.company_id=p_company_id
  for update;
  if not found then
    raise exception 'مسودة التسوية اليدوية غير موجودة في الشركة المحددة' using errcode='P0002';
  end if;

  if v_doc.source<>'manual' or v_doc.status<>'draft' then
    raise exception 'يسمح بحذف مسودة التسوية اليدوية فقط؛ محضر الجرد الفعلي أو المستند المرحل لا يمكن حذفه' using errcode='23514';
  end if;

  if not public.erp_user_has_company_role(
    p_company_id,array['owner','admin','manager','operator','accountant']::text[]
  ) then
    raise exception 'لا تملك صلاحية حذف مسودة التسوية اليدوية' using errcode='42501';
  end if;

  select w.branch_id into v_warehouse_branch
  from public.erp_warehouses w
  where w.id=v_doc.warehouse_id
    and w.company_id=p_company_id
    and w.is_active;
  if not found then
    raise exception 'المخزن المرتبط بالمسودة غير نشط أو لا يتبع الشركة' using errcode='23503';
  end if;

  if v_doc.branch_id is not null and v_doc.branch_id<>v_warehouse_branch then
    raise exception 'فرع المسودة لا يطابق فرع المخزن' using errcode='23514';
  end if;

  if not public.erp_user_can_access_warehouse_scope(
    p_company_id,v_warehouse_branch,v_doc.warehouse_id
  ) then
    raise exception 'لا تملك صلاحية الوصول إلى مخزن المسودة أو فرعه' using errcode='42501';
  end if;

  if exists(
    select 1
    from public.erp_stocktake_lines l
    where l.stocktake_id=p_stocktake_id
      and (l.company_id<>p_company_id or l.warehouse_id<>v_doc.warehouse_id)
  ) then
    raise exception 'توجد بنود تسوية لا تطابق الشركة أو المخزن المرتبط بالمسودة' using errcode='23514';
  end if;

  delete from public.erp_stocktakes
  where id=p_stocktake_id
    and company_id=p_company_id
    and source='manual'
    and status='draft'
  returning id into v_deleted;

  if v_deleted is null then
    raise exception 'تغيرت حالة المسودة أثناء الحذف؛ حدّث الشاشة وأعد المحاولة' using errcode='40001';
  end if;

  return v_deleted;
end;
$function$
;

revoke all on function public.erp_delete_manual_stock_adjustment_draft(uuid,uuid) from public;
revoke all on function public.erp_delete_manual_stock_adjustment_draft(uuid,uuid) from anon;
grant execute on function public.erp_delete_manual_stock_adjustment_draft(uuid,uuid) to authenticated;
