CREATE TABLE IF NOT EXISTS public.story_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id BIGINT NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (char_length(trim(body)) BETWEEN 1 AND 2000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS story_replies_conversation_idx
  ON public.story_replies (story_id, created_at DESC);
ALTER TABLE public.story_replies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "story_replies_read_participants" ON public.story_replies;
CREATE POLICY "story_replies_read_participants" ON public.story_replies
  FOR SELECT TO authenticated USING (sender_id = auth.uid() OR recipient_id = auth.uid());
DROP POLICY IF EXISTS "story_replies_insert_sender" ON public.story_replies;
CREATE POLICY "story_replies_insert_sender" ON public.story_replies
  FOR INSERT TO authenticated WITH CHECK (sender_id = auth.uid() AND sender_id <> recipient_id);
