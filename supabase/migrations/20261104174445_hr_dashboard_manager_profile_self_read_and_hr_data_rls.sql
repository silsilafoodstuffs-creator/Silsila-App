
drop policy if exists erp_company_member_profiles_select_admin on public.erp_company_member_profiles;
create policy erp_company_member_profiles_select_admin
on public.erp_company_member_profiles
for select
using (
  public.erp_user_has_company_role(company_id, array['owner','admin'])
  or user_id = auth.uid()
);
do $$
declare t text;
begin
  foreach t in array array['erp_hr_employee_compliance','erp_hr_training_records','erp_hr_recruitment_candidates','erp_hr_employee_movements'] loop
    execute format('drop policy if exists %I on public.%I', t || '_select_company', t);
    execute format('create policy %I on public.%I for select using (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = auth.uid() and trim(coalesce(p.job_title, '''')) = ''مدير موارد بشرية'')
    )', t || '_select_company', t, t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_hr', t);
    execute format('create policy %I on public.%I for insert with check (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = auth.uid() and trim(coalesce(p.job_title, '''')) = ''مدير موارد بشرية'')
    )', t || '_insert_hr', t, t);
    execute format('drop policy if exists %I on public.%I', t || '_update_hr', t);
    execute format('create policy %I on public.%I for update using (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = auth.uid() and trim(coalesce(p.job_title, '''')) = ''مدير موارد بشرية'')
    ) with check (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = auth.uid() and trim(coalesce(p.job_title, '''')) = ''مدير موارد بشرية'')
    )', t || '_update_hr', t, t, t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_hr', t);
    execute format('create policy %I on public.%I for delete using (
      public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager''])
      or exists (select 1 from public.erp_company_member_profiles p where p.company_id = %I.company_id and p.user_id = auth.uid() and trim(coalesce(p.job_title, '''')) = ''مدير موارد بشرية'')
    )', t || '_delete_hr', t, t);
  end loop;
end $$;
