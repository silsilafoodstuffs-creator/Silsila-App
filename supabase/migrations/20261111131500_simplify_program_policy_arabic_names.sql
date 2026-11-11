-- Normalize Arabic policy names in existing company data.
-- The screen title already supplies the context, so policy/policies is redundant.
update public.erp_program_policies
set name_ar = btrim(regexp_replace(
  regexp_replace(coalesce(name_ar, ''), '(^|[[:space:]])(سياسات|سياسة)(?=[[:space:]]|$)', ' ', 'g'),
  '[[:space:]]+', ' ', 'g'
)), updated_at = now()
where name_ar ~ '(^|[[:space:]])(سياسات|سياسة)([[:space:]]|$)';

update public.erp_program_policies
set name_ar = case policy_key
  when 'category_code.sub' then 'تكويد فئات فرعية ( يرث ك ف رئيسية )'
  when 'category_code.secondary' then 'تكويد فئات ثانوية ( يرث ك ف فرعية )'
  else name_ar
end,
updated_at = now()
where policy_key in ('category_code.sub','category_code.secondary');
