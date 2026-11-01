create or replace function public.erp_program_policy_applies(
  p_company_id uuid,
  p_policy_key text,
  p_actor_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_enabled boolean;
  v_all boolean;
  v_users jsonb;
  v_erp_user_id uuid;
begin
  -- A signed-in caller may only evaluate policy membership for their own identity.
  if auth.uid() is not null and p_actor_id is distinct from auth.uid() then
    return false;
  end if;

  if auth.uid() is not null and not public.erp_user_can_access_company(p_company_id) then
    return false;
  end if;

  select is_enabled, apply_to_all, user_ids
    into v_enabled, v_all, v_users
  from public.erp_program_policies
  where company_id=p_company_id and policy_key=p_policy_key
  limit 1;
  if not found then
    return p_policy_key='skip_quotation';
  end if;
  if not coalesce(v_enabled,false) then return false; end if;
  if coalesce(v_all,false) then return true; end if;
  if p_actor_id is null then return false; end if;
  select id into v_erp_user_id from public.erp_users
    where company_id=p_company_id and auth_user_id=p_actor_id and is_active=true limit 1;
  if v_erp_user_id is null then return false; end if;
  return coalesce(v_users,'[]'::jsonb) ? v_erp_user_id::text;
end;
$function$;
