-- Silsila performance migration: cover foreign-key lookup paths reported by Supabase advisors.
-- Additive and data-preserving; all indexes use IF NOT EXISTS.
begin;
create index if not exists idx_erp_app_activity_log_actor_id on public.erp_app_activity_log(actor_id);
create index if not exists idx_erp_app_assets_uploaded_by on public.erp_app_assets(uploaded_by);
create index if not exists idx_erp_app_role_permissions_updated_by on public.erp_app_role_permissions(updated_by);
create index if not exists idx_erp_app_theme_settings_updated_by on public.erp_app_theme_settings(updated_by);
create index if not exists idx_erp_cashboxes_account_id on public.erp_cashboxes(account_id);
create index if not exists idx_erp_cashboxes_branch_id on public.erp_cashboxes(branch_id);
create index if not exists idx_erp_company_settings_updated_by on public.erp_company_settings(updated_by);
create index if not exists idx_erp_item_categories_parent_id on public.erp_item_categories(parent_id);
create index if not exists idx_erp_journal_entries_branch_id on public.erp_journal_entries(branch_id);
create index if not exists idx_erp_journal_entries_created_by on public.erp_journal_entries(created_by);
create index if not exists idx_erp_journal_entries_fiscal_period_id on public.erp_journal_entries(fiscal_period_id);
create index if not exists idx_erp_journal_entries_posted_by on public.erp_journal_entries(posted_by);
create index if not exists idx_erp_journal_lines_branch_id on public.erp_journal_lines(branch_id);
create index if not exists idx_erp_journal_lines_party_id on public.erp_journal_lines(party_id);
create index if not exists idx_erp_warehouses_branch_id on public.erp_warehouses(branch_id);
create index if not exists idx_erp_workspace_records_created_by on public.erp_workspace_records(created_by);
create index if not exists idx_erp_workspace_records_updated_by on public.erp_workspace_records(updated_by);
create index if not exists idx_offer_items_offer_id on public.offer_items(offer_id);
create index if not exists idx_offer_items_product_id on public.offer_items(product_id);
create index if not exists idx_story_replies_recipient_id on public.story_replies(recipient_id);
create index if not exists idx_story_replies_sender_id on public.story_replies(sender_id);
create index if not exists idx_story_views_viewer_id on public.story_views(viewer_id);
create index if not exists idx_trader_market_post_interactions_user_id on public.trader_market_post_interactions(user_id);
commit;
