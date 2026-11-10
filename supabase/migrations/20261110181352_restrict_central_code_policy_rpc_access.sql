REVOKE ALL ON FUNCTION public.erp_code_policy_lock_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_code_policy_lock_status(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.erp_preview_next_extended_central_code(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_preview_next_extended_central_code(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.erp_assign_extended_central_code() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.erp_assign_workspace_item_link_code() FROM PUBLIC, anon, authenticated;
