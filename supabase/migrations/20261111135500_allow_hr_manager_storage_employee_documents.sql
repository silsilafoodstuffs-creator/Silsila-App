-- Align private Storage authorization for employee documents with the
-- public.erp_employee_documents policies: HR managers are authorized by their
-- company-scoped job assignment, not only by the broad company member role.
begin;

drop policy if exists erp_employee_docs_insert_hr on storage.objects;
create policy erp_employee_docs_insert_hr
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'erp-company-assets'
  and (storage.foldername(name))[3] = 'employee_documents'
  and exists (
    select 1
    from public.erp_companies c
    where c.id::text = (storage.foldername(objects.name))[1]
      and public.erp_user_can_access_company(c.id)
      and (
        public.erp_user_has_company_role(c.id, array['owner','admin','manager']::text[])
        or exists (
          select 1
          from public.erp_company_member_profiles p
          where p.company_id = c.id
            and p.user_id = (select auth.uid())
            and trim(coalesce(p.job_title, '')) = 'مدير موارد بشرية'
        )
      )
  )
);

drop policy if exists erp_employee_docs_delete_hr on storage.objects;
create policy erp_employee_docs_delete_hr
on storage.objects
for delete to authenticated
using (
  bucket_id = 'erp-company-assets'
  and (storage.foldername(name))[3] = 'employee_documents'
  and exists (
    select 1
    from public.erp_companies c
    where c.id::text = (storage.foldername(objects.name))[1]
      and public.erp_user_can_access_company(c.id)
      and (
        public.erp_user_has_company_role(c.id, array['owner','admin','manager']::text[])
        or exists (
          select 1
          from public.erp_company_member_profiles p
          where p.company_id = c.id
            and p.user_id = (select auth.uid())
            and trim(coalesce(p.job_title, '')) = 'مدير موارد بشرية'
        )
      )
  )
);

commit;
