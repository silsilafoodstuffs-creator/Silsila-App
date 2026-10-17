-- Silsila ERP chart-of-accounts integrity safeguards.
-- Apply after supabase/erp_schema.sql.
-- These checks protect company boundaries and parent/postable consistency.

create or replace function public.erp_validate_account_parent()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  parent_company uuid;
  parent_postable boolean;
  has_children boolean;
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'الحساب لا يمكن أن يكون أبًا لنفسه';
    end if;

    select company_id, is_postable
      into parent_company, parent_postable
    from public.erp_accounts
    where id = new.parent_id;

    if not found then
      raise exception 'الحساب الأب غير موجود';
    end if;

    if parent_company <> new.company_id then
      raise exception 'يجب أن يكون الحساب الأب تابعًا لنفس الشركة';
    end if;

    if parent_postable then
      raise exception 'لا يمكن إضافة حساب فرعي تحت حساب تحليلي قابل للترحيل';
    end if;
  end if;

  if new.is_postable then
    select exists (
      select 1 from public.erp_accounts child
      where child.parent_id = new.id
        and child.company_id = new.company_id
    ) into has_children;

    if has_children then
      raise exception 'لا يمكن جعل الحساب تجميعيًا/تحليليًا قابلًا للترحيل مع وجود حسابات تابعة';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists erp_accounts_validate_parent on public.erp_accounts;
create trigger erp_accounts_validate_parent
before insert or update of company_id, parent_id, is_postable
on public.erp_accounts
for each row execute function public.erp_validate_account_parent();

create index if not exists erp_accounts_company_parent_idx
  on public.erp_accounts(company_id, parent_id);

-- Prevent multi-level cycles when an existing account is moved under one of
-- its own descendants. The check runs in the database, not only in Flutter.
create or replace function public.erp_validate_account_parent()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  parent_company uuid;
  parent_postable boolean;
  has_children boolean;
  creates_cycle boolean;
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'الحساب لا يمكن أن يكون أبًا لنفسه';
    end if;

    select company_id, is_postable
      into parent_company, parent_postable
    from public.erp_accounts
    where id = new.parent_id;

    if not found then
      raise exception 'الحساب الأب غير موجود';
    end if;

    if parent_company <> new.company_id then
      raise exception 'يجب أن يكون الحساب الأب تابعًا لنفس الشركة';
    end if;

    if parent_postable then
      raise exception 'لا يمكن إضافة حساب فرعي تحت حساب تحليلي قابل للترحيل';
    end if;

    with recursive descendants(id) as (
      select a.id
      from public.erp_accounts a
      where a.parent_id = new.id
        and a.company_id = new.company_id
      union
      select child.id
      from public.erp_accounts child
      join descendants d on child.parent_id = d.id
      where child.company_id = new.company_id
    )
    select exists(select 1 from descendants where id = new.parent_id)
      into creates_cycle;

    if creates_cycle then
      raise exception 'لا يمكن نقل الحساب أسفل أحد الحسابات التابعة له؛ هذا ينشئ دورة في شجرة الحسابات';
    end if;
  end if;

  if new.is_postable then
    select exists (
      select 1 from public.erp_accounts child
      where child.parent_id = new.id
        and child.company_id = new.company_id
    ) into has_children;

    if has_children then
      raise exception 'لا يمكن جعل الحساب تحليليًا قابلًا للترحيل مع وجود حسابات تابعة';
    end if;
  end if;

  return new;
end;
$$;

comment on function public.erp_validate_account_parent() is
  'Enforces same-company parent links, prevents postable accounts from having children, and blocks hierarchy cycles.';
