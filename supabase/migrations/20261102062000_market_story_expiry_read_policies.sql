-- Hide expired, inactive, and archived market entries from public feeds
-- while retaining the complete owner/admin history.
drop policy if exists market_read_active on public.trader_market_posts;
drop policy if exists market_posts_read_active on public.trader_market_posts;

create policy market_posts_read_active
on public.trader_market_posts
for select
to anon, authenticated
using (
  is_active = true
  and status = 'active'
  and moderation_status = 'published'
  and expires_at > now()
);

-- Stories remain stored after expiry for the owner's history, but archived
-- stories and expired stories must not appear in public story feeds.
drop policy if exists stories_read_current on public.stories;
drop policy if exists stories_read_unexpired on public.stories;

create policy stories_read_unexpired
on public.stories
for select
to anon, authenticated
using (
  expires_at > now()
  and archived_at is null
);

create index if not exists idx_trader_market_posts_public_expiry
  on public.trader_market_posts (status, is_active, expires_at desc);

create index if not exists idx_stories_public_expiry
  on public.stories (expires_at)
  where archived_at is null;
