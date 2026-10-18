-- Silsila security hardening: trigger-only functions must not be callable as public RPCs.
-- Trigger execution does not require granting EXECUTE to authenticated users.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.silsila_handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.silsila_notify_order_events() FROM PUBLIC, anon, authenticated;
