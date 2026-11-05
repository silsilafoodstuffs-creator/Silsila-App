create table if not exists public.erp_hr_reference_catalogs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  catalog_type text not null check (catalog_type in ('employment_type','contract_type')),
  code text not null,
  name_ar text not null,
  name_en text,
  description text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_hr_reference_catalogs_code_unique unique (company_id,catalog_type,code),
  constraint erp_hr_reference_catalogs_name_unique unique (company_id,catalog_type,name_ar)
);

create index if not exists erp_hr_reference_catalogs_lookup_idx
  on public.erp_hr_reference_catalogs(company_id,catalog_type,is_active,sort_order,name_ar);

create or replace function public.erp_hr_reference_catalogs_assign_code()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_prefix text;
  v_next bigint;
  v_lock text;
begin
  if new.catalog_type not in ('employment_type','contract_type') then
    raise exception 'نوع دليل موارد بشرية غير مدعوم';
  end if;
  v_prefix := case new.catalog_type
    when 'employment_type' then 'Emt'
    when 'contract_type' then 'Cnt'
  end;
  if nullif(trim(new.code),'') is null then
    v_lock := new.company_id::text || ':hr-catalog:' || new.catalog_type;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_lock,0));
    select coalesce(max(substring(code from length(v_prefix)+1)::bigint),0)+1
      into v_next
      from public.erp_hr_reference_catalogs
      where company_id=new.company_id
        and catalog_type=new.catalog_type
        and code ~ ('^'||v_prefix||'[0-9]+$');
    new.code := v_prefix || lpad(v_next::text,4,'0');
  end if;
  return new;
end;
$$;

drop trigger if exists erp_hr_reference_catalogs_assign_code on public.erp_hr_reference_catalogs;
create trigger erp_hr_reference_catalogs_assign_code
before insert on public.erp_hr_reference_catalogs
for each row execute function public.erp_hr_reference_catalogs_assign_code();

drop trigger if exists erp_hr_reference_catalogs_updated_at on public.erp_hr_reference_catalogs;
create trigger erp_hr_reference_catalogs_updated_at
before update on public.erp_hr_reference_catalogs
for each row execute function public.erp_set_updated_at();

alter table public.erp_hr_reference_catalogs enable row level security;

drop policy if exists erp_hr_reference_catalogs_select_company on public.erp_hr_reference_catalogs;
create policy erp_hr_reference_catalogs_select_company
on public.erp_hr_reference_catalogs for select to authenticated
using (
  public.erp_user_can_access_company(company_id)
);

drop policy if exists erp_hr_reference_catalogs_insert_hr on public.erp_hr_reference_catalogs;
create policy erp_hr_reference_catalogs_insert_hr
on public.erp_hr_reference_catalogs for insert to authenticated
with check (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id=erp_hr_reference_catalogs.company_id
      and p.user_id=(select auth.uid())
      and trim(coalesce(p.job_title,'')) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية')
  )
);

drop policy if exists erp_hr_reference_catalogs_update_hr on public.erp_hr_reference_catalogs;
create policy erp_hr_reference_catalogs_update_hr
on public.erp_hr_reference_catalogs for update to authenticated
using (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id=erp_hr_reference_catalogs.company_id
      and p.user_id=(select auth.uid())
      and trim(coalesce(p.job_title,'')) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية')
  )
)
with check (
  public.erp_user_has_company_role(company_id,array['owner','admin','manager']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id=erp_hr_reference_catalogs.company_id
      and p.user_id=(select auth.uid())
      and trim(coalesce(p.job_title,'')) in ('مدير موارد بشرية','مسئول موارد بشرية','مسؤول موارد بشرية')
  )
);

drop policy if exists erp_hr_reference_catalogs_delete_hr on public.erp_hr_reference_catalogs;
create policy erp_hr_reference_catalogs_delete_hr
on public.erp_hr_reference_catalogs for delete to authenticated
using (
  public.erp_user_has_company_role(company_id,array['owner','admin']::text[])
  or exists (
    select 1 from public.erp_company_member_profiles p
    where p.company_id=erp_hr_reference_catalogs.company_id
      and p.user_id=(select auth.uid())
      and trim(coalesce(p.job_title,''))='مدير موارد بشرية'
  )
);

grant select,insert,update,delete on public.erp_hr_reference_catalogs to authenticated;
