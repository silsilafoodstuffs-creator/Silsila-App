-- Persist supplier favorites separately from product favorites.
BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS idx_favorites_user_product_unique
  ON public.favorites(user_id, product_id)
  WHERE product_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.supplier_favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  supplier_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, supplier_id),
  CHECK (user_id <> supplier_id)
);

ALTER TABLE public.supplier_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supplier_favorites_read_own" ON public.supplier_favorites;
CREATE POLICY "supplier_favorites_read_own" ON public.supplier_favorites
FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "supplier_favorites_insert_own" ON public.supplier_favorites;
CREATE POLICY "supplier_favorites_insert_own" ON public.supplier_favorites
FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "supplier_favorites_delete_own" ON public.supplier_favorites;
CREATE POLICY "supplier_favorites_delete_own" ON public.supplier_favorites
FOR DELETE TO authenticated USING (user_id = auth.uid());

COMMIT;
