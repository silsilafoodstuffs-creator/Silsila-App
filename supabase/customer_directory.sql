-- Public directory exposes only approved customer business names and classifications.
create or replace view public.customer_directory as
select id, full_name, activity_type, customer_type, governorate, district, account_status
from public.profiles
where role = 'customer'
  and account_status = any (array['approved','active','مفعل','معتمد']::text[]);
grant select on public.customer_directory to anon, authenticated;
