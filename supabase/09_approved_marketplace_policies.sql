-- Restrict publishing to approved accounts and constrain reviews to real orders.
BEGIN;

DROP POLICY IF EXISTS "products_manage_own" ON public.products;
CREATE POLICY "products_manage_own" ON public.products
FOR ALL TO authenticated
USING (
  supplier_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'supplier'
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  )
)
WITH CHECK (
  supplier_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'supplier'
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  )
);

DROP POLICY IF EXISTS "offers_manage_own" ON public.offers;
CREATE POLICY "offers_manage_own" ON public.offers
FOR ALL TO authenticated
USING (
  supplier_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'supplier'
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  )
)
WITH CHECK (
  supplier_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'supplier'
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  )
);

DROP POLICY IF EXISTS "stories_manage_own" ON public.stories;
CREATE POLICY "stories_manage_own" ON public.stories
FOR ALL TO authenticated
USING (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  )
)
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  )
);

DROP POLICY IF EXISTS "market_posts_manage_own" ON public.trader_market_posts;
CREATE POLICY "market_posts_manage_own" ON public.trader_market_posts
FOR ALL TO authenticated
USING (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  )
)
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.account_status IN ('approved', 'active', 'مفعل', 'معتمد')
  )
);

DROP POLICY IF EXISTS "reviews_create_own" ON public.reviews;
CREATE POLICY "reviews_create_own" ON public.reviews
FOR INSERT TO authenticated
WITH CHECK (
  reviewer_id = auth.uid()
  AND order_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = reviews.order_id
      AND o.status IN ('تم التسليم', 'delivered')
      AND (o.customer_id = auth.uid() OR o.supplier_id = auth.uid())
  )
  AND reviewed_user_id <> auth.uid()
);

COMMIT;
