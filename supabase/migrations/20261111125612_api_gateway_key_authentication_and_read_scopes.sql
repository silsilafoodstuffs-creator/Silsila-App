alter table public.erp_api_credentials drop constraint if exists erp_api_credentials_scopes_check;
alter table public.erp_api_credentials add constraint erp_api_credentials_scopes_check check (
  cardinality(scopes) between 1 and 12
  and scopes <@ array['read','company:read','items:read','customers:read','suppliers:read','inventory:read','orders:read']::text[]
);
create or replace function public.erp_api_key_authenticate(p_key_hash text)
returns table(key_id uuid,company_id uuid,scopes text[])
language plpgsql security definer set search_path = '' set row_security = off
as $$
begin
  if p_key_hash is null or length(p_key_hash) <> 64 then return; end if;
  return query
    update public.erp_api_credentials c
       set last_used_at=now()
     where c.key_hash=p_key_hash
       and c.revoked_at is null
       and (c.expires_at is null or c.expires_at>now())
    returning c.id,c.company_id,c.scopes;
end;
$$;
revoke all on function public.erp_api_key_authenticate(text) from public,anon,authenticated;
grant execute on function public.erp_api_key_authenticate(text) to service_role;
