-- Normalize Arabic policy names in existing company data.
-- The screen title already supplies the context, so policy/policies is redundant.
update public.erp_program_policies
set name_ar = btrim(regexp_replace(
  regexp_replace(coalesce(name_ar, ''), '(^|[[:space:]])(سياسات|سياسة)(?=[[:space:]]|$)', ' ', 'g'),
  '[[:space:]]+', ' ', 'g'
)), updated_at = now()
where name_ar ~ '(^|[[:space:]])(سياسات|سياسة)([[:space:]]|$)';
