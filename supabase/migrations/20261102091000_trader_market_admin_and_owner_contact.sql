ALTER TABLE public.trader_market_posts
  ADD COLUMN IF NOT EXISTS owner_display_name text,
  ADD COLUMN IF NOT EXISTS owner_phone text,
  ADD COLUMN IF NOT EXISTS owner_address text,
  ADD COLUMN IF NOT EXISTS duration_hours integer NOT NULL DEFAULT 24 CHECK (duration_hours BETWEEN 1 AND 720);

DROP POLICY IF EXISTS market_posts_admin_read ON public.trader_market_posts;
CREATE POLICY market_posts_admin_read ON public.trader_market_posts
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (SELECT auth.uid()) AND (p.role IN ('admin','super_admin') OR p.account_type = 'إدارة نشاط')));
DROP POLICY IF EXISTS market_posts_admin_update ON public.trader_market_posts;
CREATE POLICY market_posts_admin_update ON public.trader_market_posts
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (SELECT auth.uid()) AND (p.role IN ('admin','super_admin') OR p.account_type = 'إدارة نشاط')))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (SELECT auth.uid()) AND (p.role IN ('admin','super_admin') OR p.account_type = 'إدارة نشاط')));
DROP POLICY IF EXISTS market_posts_admin_delete ON public.trader_market_posts;
CREATE POLICY market_posts_admin_delete ON public.trader_market_posts
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (SELECT auth.uid()) AND (p.role IN ('admin','super_admin') OR p.account_type = 'إدارة نشاط')));
