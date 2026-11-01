create or replace function public.erp_guard_stocktake_lifecycle()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if tg_op='DELETE' then
    if old.source='stocktake' then
      raise exception 'تسوية الجرد الناتجة عن جرد فعلي لا يمكن إلغاؤها أو حذفها' using errcode='55000';
    end if;
    if old.status='posted' then
      raise exception 'المستند المرحل لا يمكن حذفه أو إلغاء ترحيله' using errcode='55000';
    end if;
    return old;
  end if;

  if new.source is distinct from old.source then
    raise exception 'لا يمكن تغيير مصدر مستند الجرد أو التسوية بعد إنشائه' using errcode='55000';
  end if;
  if old.status='posted' then
    raise exception 'المستند المرحل لا يمكن تعديله أو إلغاء ترحيله' using errcode='55000';
  end if;
  if old.source='stocktake' and new.status not in ('draft','posted') then
    raise exception 'مستند الجرد الفعلي يحفظ كمسودة أو يرحل فقط' using errcode='55000';
  end if;
  return new;
end;
$function$;

create or replace function public.erp_guard_stocktake_line_lifecycle()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_stocktake_id uuid;
  v_status text;
begin
  if tg_op='DELETE' then
    v_stocktake_id:=old.stocktake_id;
  else
    v_stocktake_id:=new.stocktake_id;
  end if;

  select status into v_status
  from public.erp_stocktakes
  where id=v_stocktake_id;

  if not found then
    if tg_op='DELETE' then
      return old;
    end if;
    raise exception 'محضر الجرد غير موجود' using errcode='23503';
  end if;

  if v_status='posted' then
    raise exception 'تفاصيل المستند المرحل لا يمكن تعديلها أو حذفها' using errcode='55000';
  end if;

  if tg_op='DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_erp_guard_stocktake_line_lifecycle on public.erp_stocktake_lines;
create trigger trg_erp_guard_stocktake_line_lifecycle
before insert or update or delete on public.erp_stocktake_lines
for each row execute function public.erp_guard_stocktake_line_lifecycle();

revoke all on function public.erp_guard_stocktake_lifecycle() from public, anon, authenticated;
revoke all on function public.erp_guard_stocktake_line_lifecycle() from public, anon, authenticated;
