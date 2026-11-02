ALTER TABLE public.stories DROP CONSTRAINT IF EXISTS stories_duration_minutes_check;
ALTER TABLE public.stories ADD CONSTRAINT stories_duration_minutes_check CHECK (duration_minutes BETWEEN 1 AND 1440);
