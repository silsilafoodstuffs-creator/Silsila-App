-- Add bilingual names to cost centers while retaining center_name for legacy reports.
begin;
alter table public.erp_cost_centers add column if not exists center_name_ar text;
alter table public.erp_cost_centers add column if not exists center_name_en text;
update public.erp_cost_centers set center_name_ar = center_name where center_name_ar is null or btrim(center_name_ar) = '';
alter table public.erp_cost_centers alter column center_name_ar set default '';
alter table public.erp_cost_centers alter column center_name_ar set not null;
commit;
