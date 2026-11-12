
create or replace function public.get_targeted_active_offers(
  p_activity_type text default null,
  p_limit integer default 50
)
returns setof public.offers
language sql
stable
security definer
set search_path = public
as $$
  select o.*
  from public.offers o
  left join public.profiles p on p.id = auth.uid()
  where o.is_active = true
    and (o.start_at is null or o.start_at <= now())
    and (o.ends_at is null or o.ends_at >= now())
    and (nullif(btrim(p_activity_type), '') is null or o.activity_type = p_activity_type)
    and (
      coalesce(o.target_customer_types, '[]'::jsonb) = '[]'::jsonb
      or (
        p.id is not null
        and exists (
          select 1
          from jsonb_array_elements_text(coalesce(o.target_customer_types, '[]'::jsonb)) as t(value)
          where t.value = p.customer_type
        )
      )
    )
    and (
      (
        coalesce(o.target_governorates, '[]'::jsonb) = '[]'::jsonb
        and coalesce(o.target_districts, '[]'::jsonb) = '[]'::jsonb
        and coalesce(o.target_areas, '[]'::jsonb) = '[]'::jsonb
      )
      or (
        p.id is not null
        and (
          exists (select 1 from jsonb_array_elements_text(coalesce(o.target_governorates, '[]'::jsonb)) g(value)
                  where g.value = p.governorate)
          or exists (select 1 from jsonb_array_elements_text(coalesce(o.target_districts, '[]'::jsonb)) d(value)
                     where d.value = p.district)
          or exists (select 1 from jsonb_array_elements_text(coalesce(o.target_areas, '[]'::jsonb)) a(value)
                     where a.value = p.area)
        )
      )
    )
  order by o.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;
revoke all on function public.get_targeted_active_offers(text, integer) from public;
grant execute on function public.get_targeted_active_offers(text, integer) to anon, authenticated;
