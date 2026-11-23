-- Preserve every existing RLS predicate while moving auth.uid() calls
-- into statement initplans. This is a semantics-preserving planner optimization.
begin;

alter policy erp_scope_guard_erp_cash_movements on public.erp_cash_movements
using ((erp_user_has_company_role(company_id, ARRAY['owner'::text, 'admin'::text]) OR ((created_by = (select auth.uid())) AND (cash_voucher_id IS NULL)) OR (EXISTS ( SELECT 1
   FROM erp_cash_vouchers v
  WHERE ((v.id = erp_cash_movements.cash_voucher_id) AND (v.company_id = erp_cash_movements.company_id) AND (((v.branch_id IS NOT NULL) AND erp_user_can_access_branch_scope(v.company_id, v.branch_id)) OR (EXISTS ( SELECT 1
           FROM erp_cashboxes cb
          WHERE ((cb.company_id = v.company_id) AND (cb.id = ANY (ARRAY[v.source_cashbox_id, v.destination_cashbox_id])) AND (cb.branch_id IS NOT NULL) AND erp_user_can_access_branch_scope(cb.company_id, cb.branch_id))))))))
with check ((erp_user_has_company_role(company_id, ARRAY['owner'::text, 'admin'::text]) OR ((created_by = (select auth.uid())) AND (cash_voucher_id IS NULL)) OR (EXISTS ( SELECT 1
   FROM erp_cash_vouchers v
  WHERE ((v.id = erp_cash_movements.cash_voucher_id) AND (v.company_id = erp_cash_movements.company_id) AND (((v.branch_id IS NOT NULL) AND erp_user_can_access_branch_scope(v.company_id, v.branch_id)) OR (EXISTS ( SELECT 1
           FROM erp_cashboxes cb
          WHERE ((cb.company_id = v.company_id) AND (cb.id = ANY (ARRAY[v.source_cashbox_id, v.destination_cashbox_id])) AND (cb.branch_id IS NOT NULL) AND erp_user_can_access_branch_scope(cb.company_id, cb.branch_id))))))));

alter policy erp_studio_audit_insert_admin on public.erp_studio_audit_log
with check ((erp_user_has_company_role(company_id, ARRAY['owner'::text, 'admin'::text]) AND (actor_user_id = (select auth.uid()))));

alter policy erp_studio_versions_insert_admin on public.erp_studio_design_versions
with check ((erp_user_has_company_role(company_id, ARRAY['owner'::text, 'admin'::text]) AND (created_by = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM erp_studio_designs d
  WHERE ((d.id = erp_studio_design_versions.design_id) AND (d.company_id = erp_studio_design_versions.company_id))))));

alter policy erp_studio_designs_insert_admin on public.erp_studio_designs
with check ((erp_user_has_company_role(company_id, ARRAY['owner'::text, 'admin'::text]) AND (created_by = (select auth.uid())) AND (updated_by = (select auth.uid()))));

alter policy erp_studio_designs_update_admin on public.erp_studio_designs
using (erp_user_has_company_role(company_id, ARRAY['owner'::text, 'admin'::text]))
with check ((erp_user_has_company_role(company_id, ARRAY['owner'::text, 'admin'::text]) AND (updated_by = (select auth.uid()))));

alter policy erp_studio_layout_profiles_insert_permission on public.erp_studio_layout_profiles
with check ((private.erp_studio_has_action_permission(company_id, 'layout_save'::text) AND (updated_by = (select auth.uid()))));

alter policy erp_studio_layout_profiles_update_permission on public.erp_studio_layout_profiles
using (private.erp_studio_has_action_permission(company_id, 'layout_save'::text))
with check ((private.erp_studio_has_action_permission(company_id, 'layout_save'::text) AND (updated_by = (select auth.uid()))));

alter policy story_favorites_manage_own on public.story_favorites
using ((viewer_id = (select auth.uid())))
with check ((viewer_id = (select auth.uid())));

alter policy story_hidden_manage_own on public.story_hidden
using ((viewer_id = (select auth.uid())))
with check ((viewer_id = (select auth.uid())));

alter policy supplier_offer_customer_categories_own on public.supplier_offer_customer_categories
using ((supplier_id = (select auth.uid())))
with check ((supplier_id = (select auth.uid())));

-- Cache the authenticated actor once inside the Studio permission helper.
create or replace function private.erp_studio_has_action_permission(
  p_company_id uuid,
  p_action text
)
returns boolean
language plpgsql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $function$
declare
  v_allowed boolean;
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null or p_company_id is null then
    return false;
  end if;

  if public.erp_user_has_company_role(
    p_company_id, array['owner','admin']::text[]
  ) then
    return true;
  end if;

  if not public.erp_user_can_access_company(p_company_id) then
    return false;
  end if;

  select
    coalesce(pm.can_access, false)
    and case p_action
      when 'read' then true
      when 'published_read' then true
      when 'create' then coalesce(pm.can_add, false)
      when 'save' then coalesce(pm.can_save, false)
      when 'preview' then coalesce(pm.can_preview, false)
      when 'approve' then coalesce(pm.can_edit, false)
      when 'publish' then coalesce(pm.can_edit, false)
      when 'restore' then coalesce(pm.can_edit, false)
      when 'layout_save' then coalesce(pm.can_save, false)
      when 'layout_delete' then coalesce(pm.can_delete, false)
      else false
    end
  into v_allowed
  from public.erp_user_permission_matrix pm
  where pm.company_id = p_company_id
    and pm.user_id = v_actor_id
    and pm.menu_name = 'إعدادات عامة'
    and pm.submenu_name = 'بيانات أساسية'
    and pm.page_name = case when p_action = 'published_read' then 'شاشات الاستوديو المنشورة' else 'سلسلة ستوديو' end
  limit 1;

  return coalesce(v_allowed, false);
end;
$function$;

commit;
