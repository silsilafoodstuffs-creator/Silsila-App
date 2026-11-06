-- Allow manufacturing material consumption to be recorded in the shared stock ledger.
alter table public.erp_inventory_movements drop constraint if exists erp_inventory_movements_movement_type_check;
alter table public.erp_inventory_movements add constraint erp_inventory_movements_movement_type_check
 check (movement_type = any (array['opening','purchase_receipt','sales_issue','customer_return','supplier_return','transfer_in','transfer_out','adjustment','waste','production_issue']::text[]));