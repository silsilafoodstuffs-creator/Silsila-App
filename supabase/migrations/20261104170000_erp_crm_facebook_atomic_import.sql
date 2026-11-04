-- Atomic, company-scoped Excel import for Facebook group leads.
-- The function is SECURITY INVOKER: table grants and RLS remain in force.
begin;

create or replace function public.erp_crm_facebook_import_group_leads(
  p_company_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_row jsonb;
  v_profile_id uuid;
  v_group_id uuid;
  v_profile_url text;
  v_profile_normalized text;
  v_group_url text;
  v_name text;
  v_group_name text;
  v_links_added integer := 0;
  v_profiles_processed integer := 0;
  v_groups_processed integer := 0;
  v_rows_processed integer := 0;
  v_affected integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_company_id is null
     or not public.erp_user_can_access_company(p_company_id) then
    raise exception 'Company access denied' using errcode = '42501';
  end if;

  if p_rows is null
     or jsonb_typeof(p_rows) <> 'array'
     or jsonb_array_length(p_rows) < 1
     or jsonb_array_length(p_rows) > 2000 then
    raise exception 'Import must contain between 1 and 2000 rows'
      using errcode = '22023';
  end if;

  for v_row in select value from jsonb_array_elements(p_rows)
  loop
    v_name := btrim(coalesce(v_row->>'display_name', ''));
    v_profile_url := btrim(coalesce(v_row->>'profile_url', ''));
    v_profile_normalized := btrim(coalesce(v_row->>'profile_url_normalized', ''));
    v_group_name := btrim(coalesce(v_row->>'group_name', ''));
    v_group_url := btrim(coalesce(v_row->>'group_url', ''));

    if v_name = '' or length(v_name) > 180
       or v_group_name = '' or length(v_group_name) > 180 then
      raise exception 'Invalid account or group name in import row'
        using errcode = '22023';
    end if;

    if v_profile_url !~* '^https://([a-z0-9-]+\.)?(facebook\.com|fb\.com)/'
       or v_profile_normalized !~* '^https://([a-z0-9-]+\.)?(facebook\.com|fb\.com)/'
       or v_group_url !~* '^https://([a-z0-9-]+\.)?(facebook\.com|fb\.com)/' then
      raise exception 'Only valid HTTPS Facebook profile and group URLs are accepted'
        using errcode = '22023';
    end if;

    insert into public.erp_crm_facebook_profiles(
      company_id, display_name, profile_url, profile_url_normalized,
      classification, source_method, created_by
    ) values (
      p_company_id, v_name, v_profile_url, v_profile_normalized,
      'غير محدد', 'xlsx_import', auth.uid()
    )
    on conflict (company_id, profile_url_normalized)
    do update set
      display_name = excluded.display_name,
      profile_url = excluded.profile_url,
      updated_at = now()
    returning id into v_profile_id;
    v_profiles_processed := v_profiles_processed + 1;

    insert into public.erp_crm_facebook_groups(
      company_id, group_name, group_url, created_by
    ) values (
      p_company_id, v_group_name, v_group_url, auth.uid()
    )
    on conflict (company_id, group_url_normalized)
    do update set
      group_name = excluded.group_name,
      group_url = excluded.group_url,
      updated_at = now()
    returning id into v_group_id;
    v_groups_processed := v_groups_processed + 1;

    insert into public.erp_crm_facebook_group_profiles(
      company_id, group_id, profile_id, created_by
    ) values (
      p_company_id, v_group_id, v_profile_id, auth.uid()
    )
    on conflict (company_id, group_id, profile_id) do nothing;
    get diagnostics v_affected = row_count;
    v_links_added := v_links_added + v_affected;
    v_rows_processed := v_rows_processed + 1;
  end loop;

  return jsonb_build_object(
    'rows_processed', v_rows_processed,
    'profiles_processed', v_profiles_processed,
    'groups_processed', v_groups_processed,
    'new_links', v_links_added
  );
end;
$$;

revoke all on function public.erp_crm_facebook_import_group_leads(uuid, jsonb) from public, anon;
grant execute on function public.erp_crm_facebook_import_group_leads(uuid, jsonb) to authenticated;

commit;
