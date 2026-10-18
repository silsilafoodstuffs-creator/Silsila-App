-- Secure, atomic import of a public-directory lead into one Silsila company.
-- Apply after erp_public_market_leads_staging.sql, erp_public_leads_party_fields.sql,
-- and erp_security_membership.sql.
create or replace function public.erp_import_public_lead(
  p_lead_id uuid,
  p_company_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_lead public.erp_public_lead_staging%rowtype;
  v_party_id uuid;
  v_party_kind text;
  v_party_code text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.erp_user_has_company_role(
    p_company_id,
    array['owner','admin','manager','sales_manager']::text[]
  ) then
    raise exception 'You do not have permission to import leads into this company';
  end if;

  select * into v_lead
  from public.erp_public_lead_staging
  where id = p_lead_id
  for update;

  if not found then
    raise exception 'Lead not found';
  end if;

  if v_lead.verification_status = 'imported' or v_lead.imported_party_id is not null then
    raise exception 'Lead has already been imported';
  end if;

  if v_lead.company_id is not null and v_lead.company_id <> p_company_id then
    raise exception 'Lead is already assigned to another company';
  end if;

  v_party_kind := case
    when v_lead.lead_kind in ('potential_supplier','wholesaler','manufacturer') then 'supplier'
    else 'customer'
  end;
  v_party_code := 'LEAD-' || upper(substr(replace(v_lead.id::text,'-',''),1,10));

  insert into public.erp_parties(
    company_id, party_code, party_name, party_kind, phone, address,
    governorate, district, business_classification, source_name, source_url,
    is_demo_data, is_active
  )
  values(
    p_company_id, v_party_code, v_lead.business_name, v_party_kind,
    v_lead.public_phone, v_lead.public_address, v_lead.governorate,
    v_lead.district, v_lead.business_classification, v_lead.source_name,
    v_lead.source_url, false, false
  )
  returning id into v_party_id;

  update public.erp_public_lead_staging
  set company_id = p_company_id,
      imported_party_id = v_party_id,
      verification_status = 'imported',
      verification_notes = 'Imported as inactive draft by an authorized company manager; verify the business and contact details before activation.',
      updated_at = now()
  where id = p_lead_id;

  return v_party_id;
end;
$$;

revoke all on function public.erp_import_public_lead(uuid,uuid) from public, anon;
grant execute on function public.erp_import_public_lead(uuid,uuid) to authenticated;

-- Global leads are readable, but direct client-side updates are disabled.
drop policy if exists erp_public_leads_update_manager on public.erp_public_lead_staging;
