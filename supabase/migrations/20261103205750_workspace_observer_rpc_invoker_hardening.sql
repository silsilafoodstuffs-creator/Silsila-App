-- Keep the exposed observer RPC invoker-scoped. The private helper performs
-- the narrowly scoped role check; only authenticated callers may execute it.
create or replace function public.erp_is_silsila_workspace_observer()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  select private.is_silsila_workspace_observer()
$function$;

revoke all on function public.erp_is_silsila_workspace_observer() from public, anon;
grant execute on function public.erp_is_silsila_workspace_observer() to authenticated;
grant execute on function private.is_silsila_workspace_observer() to authenticated;
