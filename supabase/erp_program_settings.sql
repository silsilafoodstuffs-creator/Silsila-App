create table if not exists public.erp_program_settings (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null unique references public.erp_companies(id) on delete cascade,
 program_name varchar(150) not null default 'سلسلة',
 language_code varchar(10) not null default 'ar',
 logo_base64 text, logo_mime_type varchar(80),
 identity_primary_color varchar(9) not null default '#3E007D',
 identity_secondary_color varchar(9) not null default '#FFA015',
 identity_accent_color varchar(9) not null default '#FF27C3',
 identity_background_color varchar(9) not null default '#FFFFFF',
 heading_styles jsonb not null default '[]'::jsonb,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id)
);
alter table public.erp_program_settings enable row level security;
drop policy if exists erp_program_settings_member_select on public.erp_program_settings;
create policy erp_program_settings_member_select on public.erp_program_settings for select to authenticated using (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_program_settings.company_id and m.user_id=auth.uid() and m.is_active=true));
drop policy if exists erp_program_settings_member_insert on public.erp_program_settings;
create policy erp_program_settings_member_insert on public.erp_program_settings for insert to authenticated with check (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_program_settings.company_id and m.user_id=auth.uid() and m.is_active=true));
drop policy if exists erp_program_settings_member_update on public.erp_program_settings;
create policy erp_program_settings_member_update on public.erp_program_settings for update to authenticated using (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_program_settings.company_id and m.user_id=auth.uid() and m.is_active=true))
 with check (exists(select 1 from public.erp_company_members m where m.company_id=erp_program_settings.company_id and m.user_id=auth.uid() and m.is_active=true));
grant select,insert,update on public.erp_program_settings to authenticated;
