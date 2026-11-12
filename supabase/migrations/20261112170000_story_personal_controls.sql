-- Per-viewer story hiding and favorite story owners.
BEGIN;
CREATE TABLE IF NOT EXISTS public.story_hidden (
  story_id BIGINT NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, viewer_id)
);
ALTER TABLE public.story_hidden ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS story_hidden_manage_own ON public.story_hidden;
CREATE POLICY story_hidden_manage_own ON public.story_hidden
  FOR ALL TO authenticated
  USING (viewer_id = auth.uid())
  WITH CHECK (viewer_id = auth.uid());

CREATE TABLE IF NOT EXISTS public.story_favorites (
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (owner_id, viewer_id),
  CHECK (owner_id <> viewer_id)
);
ALTER TABLE public.story_favorites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS story_favorites_manage_own ON public.story_favorites;
CREATE POLICY story_favorites_manage_own ON public.story_favorites
  FOR ALL TO authenticated
  USING (viewer_id = auth.uid())
  WITH CHECK (viewer_id = auth.uid());
CREATE INDEX IF NOT EXISTS idx_story_hidden_viewer ON public.story_hidden(viewer_id);
CREATE INDEX IF NOT EXISTS idx_story_favorites_viewer ON public.story_favorites(viewer_id);
COMMIT;
