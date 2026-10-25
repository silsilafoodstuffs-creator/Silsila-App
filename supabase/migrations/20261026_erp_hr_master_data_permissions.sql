-- Tighten HR master-data write permissions: company members may read, but only company managers may change the structure.
do $$
declare t text;
begin
 foreach t in array array['erp_hr_departments','erp_hr_jobs','erp_hr_work_locations'] loop
  execute format('drop policy if exists %I on public.%I', t || '_member_access', t);
  execute format('drop policy if exists %I on public.%I', t || '_read_company', t);
  execute format('drop policy if exists %I on public.%I', t || '_insert_manager', t);
  execute format('drop policy if exists %I on public.%I', t || '_update_manager', t);
  execute format('drop policy if exists %I on public.%I', t || '_delete_manager', t);
  execute format('create policy %I on public.%I for select to authenticated using (public.erp_user_can_access_company(company_id))', t || '_read_company', t);
  execute format('create policy %I on public.%I for insert to authenticated with check (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'']::text[]))', t || '_insert_manager', t);
  execute format('create policy %I on public.%I for update to authenticated using (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'']::text[])) with check (public.erp_user_has_company_role(company_id, array[''owner'',''admin'',''manager'']::text[]))', t || '_update_manager', t);
  execute format('create policy %I on public.%I for delete to authenticated using (public.erp_user_has_company_role(company_id, array[''owner'',''admin'']::text[]))', t || '_delete_manager', t);
 end loop;
end $$;
