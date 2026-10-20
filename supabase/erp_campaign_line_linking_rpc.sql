-- Keep the existing atomic line workflow while linking selected offer rows to sales lines.
create or replace function public.erp_add_operational_document_lines_v2(
  p_document_id uuid,
  p_kind text,
  p_lines jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_line jsonb;
  v_line_id uuid;
  v_count integer := 0;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'اختر صنفًا واحدًا على الأقل.';
  end if;
  if jsonb_array_length(p_lines) > 500 then
    raise exception 'لا يمكن إضافة أكثر من 500 سطر دفعة واحدة.';
  end if;
  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_line_id := public.erp_add_operational_document_line_v2(
      p_document_id, p_kind,
      (v_line->>'item_id')::uuid,
      (v_line->>'quantity')::numeric,
      (v_line->>'unit_price')::numeric,
      coalesce((v_line->>'discount')::numeric, 0),
      coalesce((v_line->>'tax')::numeric, 0),
      nullif(v_line->>'unit_id','')::uuid
    );
    if p_kind='sales' and nullif(v_line->>'campaign_item_id','') is not null then
      update public.erp_sales_lines
      set campaign_item_id=(v_line->>'campaign_item_id')::uuid
      where id=v_line_id and document_id=p_document_id;
      if not found then raise exception 'تعذر ربط بند العرض بسطر الفاتورة.'; end if;
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.erp_add_operational_document_lines_v2(uuid,text,jsonb) from public, anon;
grant execute on function public.erp_add_operational_document_lines_v2(uuid,text,jsonb) to authenticated;
