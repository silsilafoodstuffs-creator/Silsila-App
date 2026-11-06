-- The public profile directory is intended for marketplace participants.
-- Never expose platform-management accounts through this public view.
CREATE OR REPLACE VIEW public.profile_public_directory AS
SELECT id, full_name, avatar_url, role, account_type
FROM public.profiles
WHERE account_status = ANY (ARRAY['approved','active','مفعل','معتمد']::text[])
  AND role NOT IN ('management','admin','platform_admin','super_admin');
