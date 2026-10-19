-- Apply this migration to existing Supabase projects to enable five managed app banners.
-- The application still uses the private erp-app-assets bucket and company-scoped RLS policies.
alter table public.erp_app_assets
  drop constraint if exists erp_app_assets_asset_type_check;

alter table public.erp_app_assets
  add constraint erp_app_assets_asset_type_check
  check (asset_type in (
    'app_logo',
    'splash',
    'app_icon',
    'category',
    'item',
    'supplier',
    'customer',
    'shipping_company',
    'banner_ad',
    'other'
  ));
