-- Consent-first WhatsApp contact import tables.
begin;
create table if not exists public.erp_whatsapp_import_batches (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 source_label text not null default '',
 source_file_name text not null default '',
 source_type text not null check (source_type in ('csv','vcard','manual','official_api')),
 total_contacts integer not null default 0 check (total_contacts >= 0),
 created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now()
);
create table if not exists public.erp_whatsapp_import_contacts (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.erp_companies(id) on delete cascade,
 batch_id uuid not null references public.erp_whatsapp_import_batches(id) on delete cascade,
 contact_name text not null default '',
 phone text not null,
 normalized_phone text not null,
 group_name text not null default '',
 source_type text not null default 'uploaded_file' check (source_type in ('uploaded_file','csv','vcard','official_api','manual')),
 consent_status text not null default 'pending' check (consent_status in ('pending','consented','declined')),
 consent_evidence text,
 consented_at timestamptz,
 consented_by uuid references auth.users(id) on delete set null,
 created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint erp_whatsapp_contact_batch_phone_uk unique (batch_id, normalized_phone),
 constraint erp_whatsapp_contact_phone_nonempty check (length(regexp_replace(normalized_phone, '[^0-9]', '', 'g')) >= 7),
 constraint erp_whatsapp_contact_consent_consistency check (
  (consent_status = 'consented' and consented_at is not null and consented_by is not null)
  or (consent_status <> 'consented' and consented_at is null and consented_by is null)
 )
);
create index if not exists erp_whatsapp_batches_company_created_idx on public.erp_whatsapp_import_batches(company_id, created_at desc);
create index if not exists erp_whatsapp_contacts_company_status_idx on public.erp_whatsapp_import_contacts(company_id, consent_status, created_at desc);
create index if not exists erp_whatsapp_contacts_phone_idx on public.erp_whatsapp_import_contacts(company_id, normalized_phone);
create or replace function public.erp_whatsapp_contact_set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists erp_whatsapp_contacts_updated_at on public.erp_whatsapp_import_contacts;
create trigger erp_whatsapp_contacts_updated_at before update on public.erp_whatsapp_import_contacts
for each row execute function public.erp_whatsapp_contact_set_updated_at();
alter table public.erp_whatsapp_import_batches enable row level security;
alter table public.erp_whatsapp_import_contacts enable row level security;
drop policy if exists erp_whatsapp_batches_company_select on public.erp_whatsapp_import_batches;
create policy erp_whatsapp_batches_company_select on public.erp_whatsapp_import_batches
for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_whatsapp_batches_company_insert on public.erp_whatsapp_import_batches;
create policy erp_whatsapp_batches_company_insert on public.erp_whatsapp_import_batches
for insert to authenticated with check (public.erp_user_can_access_company(company_id) and created_by = (select auth.uid()));
drop policy if exists erp_whatsapp_contacts_company_select on public.erp_whatsapp_import_contacts;
create policy erp_whatsapp_contacts_company_select on public.erp_whatsapp_import_contacts
for select to authenticated using (public.erp_user_can_access_company(company_id));
drop policy if exists erp_whatsapp_contacts_company_insert on public.erp_whatsapp_import_contacts;
create policy erp_whatsapp_contacts_company_insert on public.erp_whatsapp_import_contacts
for insert to authenticated with check (
 public.erp_user_can_access_company(company_id)
 and created_by = (select auth.uid())
 and exists (select 1 from public.erp_whatsapp_import_batches b where b.id = batch_id and b.company_id = erp_whatsapp_import_contacts.company_id)
);
drop policy if exists erp_whatsapp_contacts_company_update on public.erp_whatsapp_import_contacts;
create policy erp_whatsapp_contacts_company_update on public.erp_whatsapp_import_contacts
for update to authenticated using (public.erp_user_can_access_company(company_id))
with check (
 public.erp_user_can_access_company(company_id)
 and ((consent_status = 'consented' and consented_by = (select auth.uid()) and consented_at is not null)
   or (consent_status <> 'consented' and consented_by is null and consented_at is null))
);
drop policy if exists erp_whatsapp_contacts_company_delete on public.erp_whatsapp_import_contacts;
create policy erp_whatsapp_contacts_company_delete on public.erp_whatsapp_import_contacts
for delete to authenticated using (public.erp_user_can_access_company(company_id));
grant select, insert on public.erp_whatsapp_import_batches to authenticated;
grant select, insert, update, delete on public.erp_whatsapp_import_contacts to authenticated;
commit;
