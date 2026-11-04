-- Explicitly restrict API table privileges to the intended authenticated operations.
begin;
revoke all privileges on table public.erp_whatsapp_import_batches from public, anon, authenticated;
revoke all privileges on table public.erp_whatsapp_import_contacts from public, anon, authenticated;
grant select, insert on table public.erp_whatsapp_import_batches to authenticated;
grant select, insert, update, delete on table public.erp_whatsapp_import_contacts to authenticated;
commit;
