create or replace function public.erp_save_physical_stocktake_counts(
 p_stocktake_id uuid,p_counts jsonb
) returns integer
language plpgsql security definer set search_path=''
as $$
declare v_doc public.erp_stocktakes%rowtype; v_expected integer; v_payload integer; v_updated integer;
begin
 select * into v_doc from public.erp_stocktakes where id=p_stocktake_id for update;
 if not found then raise exception 'محضر الجرد غير موجود'; end if;
 if auth.uid() is null or not public.erp_user_can_access_company(v_doc.company_id) then
   raise exception 'غير مصرح بحفظ محضر الجرد' using errcode='42501';
 end if;
 if v_doc.source<>'stocktake' or v_doc.status<>'draft' then raise exception 'لا يمكن تعديل محضر جرد مرحل أو غير فعلي'; end if;
 if jsonb_typeof(p_counts)<>'array' then raise exception 'صيغة كميات الجرد غير صحيحة'; end if;
 select count(*) into v_expected from public.erp_stocktake_lines where stocktake_id=p_stocktake_id;
 select count(distinct x.line_id),count(*) filter(where x.counted_quantity<0)
 into v_payload,v_updated
 from jsonb_to_recordset(p_counts) as x(line_id uuid,counted_quantity numeric);
 if v_payload<>v_expected then raise exception 'قائمة كميات الجرد غير مكتملة أو تحتوي معرفات مكررة'; end if;
 if v_updated>0 then raise exception 'لا يمكن إدخال كمية جرد سالبة'; end if;
 update public.erp_stocktake_lines l set counted_quantity=x.counted_quantity
 from jsonb_to_recordset(p_counts) as x(line_id uuid,counted_quantity numeric)
 where l.id=x.line_id and l.stocktake_id=p_stocktake_id;
 get diagnostics v_updated=row_count;
 if v_updated<>v_expected then raise exception 'بعض بنود الجرد لا تتبع هذا المحضر'; end if;
 return v_updated;
end $$;