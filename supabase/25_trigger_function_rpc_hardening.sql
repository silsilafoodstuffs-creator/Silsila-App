-- Silsila security hardening: trigger-only functions must not be callable as public RPCs.
-- Trigger execution does not require granting EXECUTE to authenticated users.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.silsila_handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.silsila_notify_order_events() FROM PUBLIC, anon, authenticated;

-- ERP trigger-only functions: these are invoked by database triggers, not by app RPC calls.
-- Keep EXECUTE revoked from client-facing roles while preserving trigger behavior.
REVOKE EXECUTE ON FUNCTION public.erp_capture_sales_invoice_audit() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.erp_enforce_employee_national_id_policy() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.erp_enforce_purchase_document_chain_policy() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.erp_enforce_sales_document_chain_policy() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.erp_guard_fiscal_period() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.erp_guard_sales_document_owner_edit() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.erp_validate_master_data_links() FROM PUBLIC, anon, authenticated;

-- This policy helper is needed by authenticated RLS checks, but must not be callable anonymously.
REVOKE EXECUTE ON FUNCTION public.erp_program_policy_applies(uuid, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_program_policy_applies(uuid, text, uuid) TO authenticated;
