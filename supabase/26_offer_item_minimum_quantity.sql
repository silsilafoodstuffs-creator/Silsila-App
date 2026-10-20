-- Silsila migration 26: minimum quantity per offer item.
-- Run after migrations 01-25 in the Supabase SQL Editor.
begin;

alter table public.offer_items
  add column if not exists min_quantity numeric(12,3) not null default 1;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'offer_items_min_quantity_positive'
      and conrelid = 'public.offer_items'::regclass
  ) then
    alter table public.offer_items
      add constraint offer_items_min_quantity_positive
      check (min_quantity > 0);
  end if;
end
$$;

commit;
