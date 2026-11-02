ALTER TABLE public.trader_market_posts
  DROP CONSTRAINT IF EXISTS trader_market_posts_post_type_check;
ALTER TABLE public.trader_market_posts
  ADD CONSTRAINT trader_market_posts_post_type_check
  CHECK (post_type IN ('buy','sell','transfer'));

ALTER TABLE public.trader_market_posts
  ADD COLUMN IF NOT EXISTS items_data jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS published_at timestamptz,
  ADD COLUMN IF NOT EXISTS extended_hours integer NOT NULL DEFAULT 0 CHECK (extended_hours >= 0),
  ADD COLUMN IF NOT EXISTS quality_preference text CHECK (quality_preference IS NULL OR quality_preference IN ('good','near_expiry','any')),
  ADD COLUMN IF NOT EXISTS expiry_condition_date date,
  ADD COLUMN IF NOT EXISTS seller_buyer_role text CHECK (seller_buyer_role IS NULL OR seller_buyer_role IN ('seller','buyer')),
  ADD COLUMN IF NOT EXISTS freight_payer text CHECK (freight_payer IS NULL OR freight_payer IN ('seller','buyer')),
  ADD COLUMN IF NOT EXISTS freight_collection_point text CHECK (freight_collection_point IS NULL OR freight_collection_point IN ('loading','unloading')),
  ADD COLUMN IF NOT EXISTS pickup_location text,
  ADD COLUMN IF NOT EXISTS delivery_location text,
  ADD COLUMN IF NOT EXISTS requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS moderation_status text NOT NULL DEFAULT 'published' CHECK (moderation_status IN ('draft','pending_review','published','rejected','archived'));

UPDATE public.trader_market_posts
SET published_at = COALESCE(published_at, created_at),
    expires_at = COALESCE(expires_at, created_at + interval '24 hours')
WHERE published_at IS NULL OR expires_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_trader_market_posts_active_expiry
  ON public.trader_market_posts (is_active, status, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_trader_market_posts_owner_history
  ON public.trader_market_posts (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trader_market_posts_type_activity
  ON public.trader_market_posts (post_type, activity_type, published_at DESC);

ALTER TABLE public.stories
  ADD COLUMN IF NOT EXISTS archived_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS duration_minutes integer NOT NULL DEFAULT 60 CHECK (duration_minutes BETWEEN 1 AND 60);

CREATE INDEX IF NOT EXISTS idx_stories_owner_history
  ON public.stories (user_id, created_at DESC);
