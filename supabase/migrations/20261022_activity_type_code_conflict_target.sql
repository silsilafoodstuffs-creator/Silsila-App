-- Make code a standard unique conflict target for PostgREST upserts.
DROP INDEX IF EXISTS public.activity_types_code_uidx;
CREATE UNIQUE INDEX activity_types_code_uidx
  ON public.activity_types (code);