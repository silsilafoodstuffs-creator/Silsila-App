-- Avoid re-evaluating auth.uid() for every row in the affected RLS policies.
-- Wrapping it in a scalar SELECT preserves authorization semantics and allows init-plan evaluation.
alter policy erp_company_member_profiles_insert_admin on public.erp_company_member_profiles
with check (
  ((updated_by is null) or (updated_by = (select auth.uid())))
  and public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
  and exists (
    select 1 from public.erp_company_members m
    where m.company_id = erp_company_member_profiles.company_id
      and m.user_id = erp_company_member_profiles.user_id
  )
);
alter policy erp_company_member_profiles_update_admin on public.erp_company_member_profiles
using (public.erp_user_has_company_role(company_id, array['owner','admin']::text[]))
with check (
  ((updated_by is null) or (updated_by = (select auth.uid())))
  and public.erp_user_has_company_role(company_id, array['owner','admin']::text[])
);
alter policy erp_sales_fulfillment_member_insert on public.erp_sales_fulfillment_documents
with check (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_sales_fulfillment_documents.company_id
    and m.user_id = (select auth.uid()) and m.is_active = true
));
alter policy erp_sales_fulfillment_member_select on public.erp_sales_fulfillment_documents
using (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_sales_fulfillment_documents.company_id
    and m.user_id = (select auth.uid()) and m.is_active = true
));
alter policy erp_sales_fulfillment_member_update on public.erp_sales_fulfillment_documents
using (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_sales_fulfillment_documents.company_id
    and m.user_id = (select auth.uid()) and m.is_active = true
))
with check (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_sales_fulfillment_documents.company_id
    and m.user_id = (select auth.uid()) and m.is_active = true
));
alter policy erp_user_permissions_member_insert on public.erp_user_permissions
with check (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_user_permissions.company_id
    and m.user_id = (select auth.uid()) and m.is_active = true
    and m.member_role = any (array['owner','admin']::text[])
));
alter policy erp_user_permissions_member_select on public.erp_user_permissions
using (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_user_permissions.company_id
    and m.user_id = (select auth.uid()) and m.is_active = true
    and m.member_role = any (array['owner','admin']::text[])
));
alter policy erp_user_permissions_member_update on public.erp_user_permissions
using (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_user_permissions.company_id
    and m.user_id = (select auth.uid()) and m.is_active = true
    and m.member_role = any (array['owner','admin']::text[])
))
with check (exists (
  select 1 from public.erp_company_members m
  where m.company_id = erp_user_permissions.company_id
    and m.user_id = (select auth.uid()) and m.is_active = true
    and m.member_role = any (array['owner','admin']::text[])
));
alter policy erp_user_permissions_self_select on public.erp_user_permissions
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.erp_company_members m
    where m.company_id = erp_user_permissions.company_id
      and m.user_id = (select auth.uid()) and m.is_active = true
  )
);
