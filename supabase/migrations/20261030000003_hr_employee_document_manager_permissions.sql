drop policy if exists erp_employee_documents_delete_admin on public.erp_employee_documents;
create policy erp_employee_documents_delete_admin on public.erp_employee_documents
  for delete to authenticated
  using (public.erp_user_has_company_role(company_id, array['owner','admin','manager']::text[]));

drop policy if exists erp_employee_docs_delete_hr on storage.objects;
create policy erp_employee_docs_delete_hr on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'erp-company-assets'
    and (storage.foldername(name))[3] = 'employee_documents'
    and exists (
      select 1 from public.erp_companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.erp_user_has_company_role(c.id, array['owner','admin','manager']::text[])
    )
  );
