-- This RPC rewrites the company's geographic codes and re-triggers customer
-- code generation. It has no application call site; keep it off the client API.
-- A trusted server-side maintenance path may still invoke it with service_role.
begin;

revoke all on function public.erp_rebuild_geographic_hierarchical_codes(uuid)
  from public, anon, authenticated;

grant execute on function public.erp_rebuild_geographic_hierarchical_codes(uuid)
  to service_role;

commit;
