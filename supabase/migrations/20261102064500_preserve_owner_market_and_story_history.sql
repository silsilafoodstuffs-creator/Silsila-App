-- Owners must be able to inspect their own expired market requests and
-- stories. Public feeds remain restricted to unexpired, published entries.
-- Keep write permissions separate from owner history reads.

drop policy if exists market_posts_manage_own on public.trader_market_posts;
drop policy if exists market_posts_read_own_history on public.trader_market_posts;
create policy market_posts_read_own_history
on public.trader_market_posts
for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists stories_manage_own on public.stories;
drop policy if exists stories_read_own_history on public.stories;
create policy stories_read_own_history
on public.stories
for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists stories_update_own on public.stories;
create policy stories_update_own
on public.stories
for update
to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.account_status = any(array['approved','active','مفعل','معتمد'])
  )
)
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.account_status = any(array['approved','active','مفعل','معتمد'])
  )
);
