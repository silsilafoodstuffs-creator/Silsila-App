BEGIN;

INSERT INTO public.activity_types
  (code, name, name_en, sort_order, is_active, show_in_app)
VALUES
  ('ACT020', 'كتب ومطبوعات', 'Books & Publications', 20, true, true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  name_en = EXCLUDED.name_en,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  show_in_app = EXCLUDED.show_in_app;

COMMIT;
