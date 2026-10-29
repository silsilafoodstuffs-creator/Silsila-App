alter table public.erp_employees
  add column if not exists work_unit text not null default 'مكتب إداري';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.erp_employees'::regclass
      and conname = 'erp_employees_work_unit_check'
  ) then
    alter table public.erp_employees
      add constraint erp_employees_work_unit_check
      check (work_unit in ('مكتب إداري', 'مخازن', 'سيارات'));
  end if;
end $$;

create table if not exists public.erp_employee_documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  employee_id uuid not null references public.erp_employees(id) on delete cascade,
  doc_type text not null check (doc_type in (
    'personal_id','birth_certificate','qualification','labor_card','insurance_print',
    'military_status','criminal_record','trust_receipt','health_certificate',
    'driving_license','bank_account'
  )),
  file_name text not null,
  storage_path text not null unique,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 8388608),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create index if not exists erp_employee_documents_employee_idx
  on public.erp_employee_documents(company_id, employee_id, doc_type, created_at desc);

alter table public.erp_employee_documents enable row level security;
grant select, insert, update, delete on public.erp_employee_documents to authenticated;

drop policy if exists erp_employee_documents_select_member on public.erp_employee_documents;
create policy erp_employee_documents_select_member on public.erp_employee_documents
  for select to authenticated
  using (public.erp_user_can_access_company(company_id));

drop policy if exists erp_employee_documents_insert_hr on public.erp_employee_documents;
create policy erp_employee_documents_insert_hr on public.erp_employee_documents
  for insert to authenticated
  with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));

drop policy if exists erp_employee_documents_update_hr on public.erp_employee_documents;
create policy erp_employee_documents_update_hr on public.erp_employee_documents
  for update to authenticated
  using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]))
  with check (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));

drop policy if exists erp_employee_documents_delete_admin on public.erp_employee_documents;
create policy erp_employee_documents_delete_admin on public.erp_employee_documents
  for delete to authenticated
  using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists erp_employee_docs_insert_hr on storage.objects;
create policy erp_employee_docs_insert_hr on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'erp-company-assets'
    and (storage.foldername(name))[3] = 'employee_documents'
    and exists (
      select 1 from public.erp_companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.erp_user_has_company_role(c.id, array['owner','admin','manager']::text[])
    )
  );

drop policy if exists erp_employee_docs_delete_hr on storage.objects;
create policy erp_employee_docs_delete_hr on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'erp-company-assets'
    and (storage.foldername(name))[3] = 'employee_documents'
    and exists (
      select 1 from public.erp_companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.erp_user_has_company_role(c.id, array['owner','admin']::text[])
    )
  );
