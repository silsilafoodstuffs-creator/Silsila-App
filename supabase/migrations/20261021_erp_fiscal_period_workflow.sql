-- Fiscal period integrity and controlled closing.
-- Apply after erp_schema.sql and erp_security_membership.sql.

create or replace function public.erp_guard_fiscal_period()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(new.company_id::text || ':fiscal-period', 0));
  if nullif(trim(new.period_name), '') is null then raise exception 'اسم الفترة المالية مطلوب'; end if;
  if new.ends_on < new.starts_on then
    raise exception 'نهاية الفترة المالية يجب ألا تسبق بدايتها';
  end if;

  if exists (
    select 1 from public.erp_fiscal_periods p
    where p.company_id = new.company_id and p.id is distinct from new.id
      and daterange(p.starts_on, p.ends_on, '[]') && daterange(new.starts_on, new.ends_on, '[]')
  ) then
    raise exception 'الفترة المالية تتداخل مع فترة أخرى للشركة نفسها';
  end if;

  if tg_op = 'UPDATE' and old.company_id is distinct from new.company_id then
    raise exception 'لا يمكن نقل فترة مالية إلى شركة أخرى';
  end if;

  if tg_op = 'UPDATE' and old.status = 'closed' and new.status <> 'closed' then
    raise exception 'الفترة المالية المغلقة لا تُفتح مرة أخرى من شاشة التشغيل';
  end if;

  if tg_op = 'UPDATE' and old.status = 'closed'
     and (old.starts_on is distinct from new.starts_on
       or old.ends_on is distinct from new.ends_on
       or old.period_name is distinct from new.period_name) then
    raise exception 'بيانات الفترة المالية المغلقة غير قابلة للتغيير';
  end if;

  if tg_op = 'UPDATE'
     and (old.starts_on is distinct from new.starts_on or old.ends_on is distinct from new.ends_on)
     and exists (
       select 1 from public.erp_journal_entries e
       where e.company_id = old.company_id and e.status = 'posted'
         and e.entry_date between old.starts_on and old.ends_on
     ) then
    raise exception 'لا يمكن تغيير تواريخ فترة تحتوي على قيود مرحّلة';
  end if;

  if new.status = 'closed' and exists (
    select 1 from public.erp_journal_entries e
    where e.company_id = new.company_id
      and e.entry_date between new.starts_on and new.ends_on
      and e.status = 'draft'
  ) then
    raise exception 'لا يمكن إقفال الفترة قبل ترحيل المسودات أو إلغائها';
  end if;

  return new;
end;
$$;

drop trigger if exists erp_fiscal_period_guard on public.erp_fiscal_periods;
create trigger erp_fiscal_period_guard
before insert or update on public.erp_fiscal_periods
for each row execute function public.erp_guard_fiscal_period();

comment on function public.erp_guard_fiscal_period() is
  'Prevents overlapping fiscal periods and blocks closing while draft journals remain.';
