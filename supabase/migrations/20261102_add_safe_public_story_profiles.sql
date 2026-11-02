-- Expose only the public identity fields needed by story cards.
-- Direct reads from profiles remain row-scoped to the current user.
BEGIN;

CREATE OR REPLACE VIEW public.profile_public_directory AS
SELECT id, full_name, avatar_url, role, account_type
FROM public.profiles
WHERE account_status IN ('approved', 'active', 'مفعل', 'معتمد');

ALTER VIEW public.profile_public_directory SET (security_invoker = false);
REVOKE ALL ON public.profile_public_directory FROM PUBLIC;
GRANT SELECT ON public.profile_public_directory TO anon, authenticated;

COMMIT;
