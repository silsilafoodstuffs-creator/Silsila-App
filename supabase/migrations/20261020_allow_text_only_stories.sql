-- Stories support text-only posts; media duration remains bounded in StoryService.
ALTER TABLE public.stories ALTER COLUMN media_url DROP NOT NULL;
