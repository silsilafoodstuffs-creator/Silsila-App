-- Company-scoped Facebook group lead records; no scraping or Facebook session tokens.
begin;
create table if not exists public.erp_crm_facebook_groups(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.erp_companies(id) on delete cascade,
 group_name text not null check(length(btrim(group_name)) between 1 and 180),
 group_url text not null check(group_url ~ '^https://([a-z0-9-]+\.)?(facebook\.com|fb\.com)/'),
 group_url_normalized text generated always as(lower(regexp_replace(group_url,'/+$',''))) stored,
 notes text,created_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(company_id,id),unique(company_id,group_url_normalized));
create table if not exists public.erp_crm_facebook_profiles(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.erp_companies(id) on delete cascade,
 display_name text not null check(length(btrim(display_name)) between 1 and 180),
 profile_url text not null check(profile_url ~ '^https://([a-z0-9-]+\.)?(facebook\.com|fb\.com)/'),
 profile_url_normalized text not null,avatar_url text check(avatar_url is null or avatar_url ~ '^https://'),
 classification text not null default 'غير محدد' check(classification in('غير محدد','عميل محتمل','مورد محتمل','تاجر جملة','مستهلك','شركة شحن','غير مناسب')),
 notes text,source_method text not null default 'manual' check(source_method in('manual','xlsx_import')),
 created_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(company_id,id),unique(company_id,profile_url_normalized));
create table if not exists public.erp_crm_facebook_group_profiles(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.erp_companies(id) on delete cascade,
 group_id uuid not null,profile_id uuid not null,created_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 foreign key(company_id,group_id) references public.erp_crm_facebook_groups(company_id,id) on delete cascade,
 foreign key(company_id,profile_id) references public.erp_crm_facebook_profiles(company_id,id) on delete cascade,
 unique(company_id,group_id,profile_id));
create table if not exists public.erp_crm_facebook_interactions(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.erp_companies(id) on delete cascade,
 profile_id uuid not null,interaction_type text not null check(length(btrim(interaction_type)) between 1 and 100),
 interaction_at timestamptz not null default now(),notes text,created_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 foreign key(company_id,profile_id) references public.erp_crm_facebook_profiles(company_id,id) on delete cascade);
create index if not exists idx_erp_crm_fb_groups_company on public.erp_crm_facebook_groups(company_id,group_name);
create index if not exists idx_erp_crm_fb_profiles_company on public.erp_crm_facebook_profiles(company_id,display_name);
create index if not exists idx_erp_crm_fb_links_profile on public.erp_crm_facebook_group_profiles(company_id,profile_id);
create index if not exists idx_erp_crm_fb_links_group on public.erp_crm_facebook_group_profiles(company_id,group_id);
create index if not exists idx_erp_crm_fb_interactions_profile on public.erp_crm_facebook_interactions(company_id,profile_id,interaction_at desc);
alter table public.erp_crm_facebook_groups enable row level security;
alter table public.erp_crm_facebook_profiles enable row level security;
alter table public.erp_crm_facebook_group_profiles enable row level security;
alter table public.erp_crm_facebook_interactions enable row level security;
drop policy if exists erp_crm_fb_groups_company_access on public.erp_crm_facebook_groups;
create policy erp_crm_fb_groups_company_access on public.erp_crm_facebook_groups for all to authenticated using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));
drop policy if exists erp_crm_fb_profiles_company_access on public.erp_crm_facebook_profiles;
create policy erp_crm_fb_profiles_company_access on public.erp_crm_facebook_profiles for all to authenticated using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));
drop policy if exists erp_crm_fb_links_company_access on public.erp_crm_facebook_group_profiles;
create policy erp_crm_fb_links_company_access on public.erp_crm_facebook_group_profiles for all to authenticated using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));
drop policy if exists erp_crm_fb_interactions_company_access on public.erp_crm_facebook_interactions;
create policy erp_crm_fb_interactions_company_access on public.erp_crm_facebook_interactions for all to authenticated using(public.erp_user_can_access_company(company_id)) with check(public.erp_user_can_access_company(company_id));
revoke all on public.erp_crm_facebook_groups,public.erp_crm_facebook_profiles,public.erp_crm_facebook_group_profiles,public.erp_crm_facebook_interactions from anon;
grant select,insert,update,delete on public.erp_crm_facebook_groups,public.erp_crm_facebook_profiles,public.erp_crm_facebook_group_profiles,public.erp_crm_facebook_interactions to authenticated;
commit;
