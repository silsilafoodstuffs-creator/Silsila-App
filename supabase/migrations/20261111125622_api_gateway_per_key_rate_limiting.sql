create table if not exists public.erp_api_usage_buckets (
  key_id uuid not null references public.erp_api_credentials(id) on delete cascade,
  window_start timestamptz not null,
  request_count integer not null default 0 check (request_count between 0 and 61),
  primary key(key_id,window_start)
);
alter table public.erp_api_usage_buckets enable row level security;
revoke all on public.erp_api_usage_buckets from public,anon,authenticated;
grant all on public.erp_api_usage_buckets to service_role;
create or replace function public.erp_api_consume_rate_limit(p_key_id uuid,p_limit integer default 60)
returns boolean language plpgsql security definer set search_path = '' set row_security = off
as $$
declare v_window timestamptz := date_trunc('minute',now()); v_count integer;
begin
  if p_key_id is null or p_limit<1 or p_limit>600 then return false; end if;
  insert into public.erp_api_usage_buckets(key_id,window_start,request_count)
  values(p_key_id,v_window,1)
  on conflict(key_id,window_start) do update
    set request_count=public.erp_api_usage_buckets.request_count+1
    where public.erp_api_usage_buckets.request_count<p_limit
  returning request_count into v_count;
  delete from public.erp_api_usage_buckets where window_start < v_window - interval '2 hours';
  return v_count is not null and v_count<=p_limit;
end;
$$;
revoke all on function public.erp_api_consume_rate_limit(uuid,integer) from public,anon,authenticated;
grant execute on function public.erp_api_consume_rate_limit(uuid,integer) to service_role;
