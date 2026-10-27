ALTER TABLE public.activity_types
  ADD COLUMN IF NOT EXISTS name_en text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS show_in_app boolean NOT NULL DEFAULT true;

-- Public/app catalog must honor both flags; ERP admins retain their separate policy.
DROP POLICY IF EXISTS activity_types_read_active ON public.activity_types;
CREATE POLICY activity_types_read_active
  ON public.activity_types FOR SELECT TO anon, authenticated
  USING (is_active = true AND show_in_app = true);

GRANT SELECT ON public.activity_types TO anon, authenticated;
