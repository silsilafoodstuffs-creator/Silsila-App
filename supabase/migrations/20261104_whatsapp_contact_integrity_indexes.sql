-- Add covering indexes and protect immutable WhatsApp import ownership fields.
begin;
create index if not exists erp_whatsapp_batches_created_by_idx on public.erp_whatsapp_import_batches(created_by);
create index if not exists erp_whatsapp_contacts_created_by_idx on public.erp_whatsapp_import_contacts(created_by);
create index if not exists erp_whatsapp_contacts_consented_by_idx on public.erp_whatsapp_import_contacts(consented_by);
create or replace function public.erp_whatsapp_contact_guard_update()
returns trigger language plpgsql set search_path = public as $$
begin
 if new.id is distinct from old.id
   or new.company_id is distinct from old.company_id
   or new.batch_id is distinct from old.batch_id
   or new.created_by is distinct from old.created_by
   or new.created_at is distinct from old.created_at then
   raise exception 'لا يمكن تغيير هوية السجل أو الشركة أو دفعة الاستيراد أو منشئ السجل';
 end if;
 if new.consent_status = 'consented' then
   if new.consented_by is distinct from (select auth.uid()) or new.consented_at is null then
     raise exception 'توثيق الموافقة يتطلب المستخدم الحالي وتاريخًا واضحًا';
   end if;
 else
   new.consented_by := null;
   new.consented_at := null;
 end if;
 return new;
end;
$$;
drop trigger if exists erp_whatsapp_contact_update_guard on public.erp_whatsapp_import_contacts;
create trigger erp_whatsapp_contact_update_guard
before update on public.erp_whatsapp_import_contacts
for each row execute function public.erp_whatsapp_contact_guard_update();
commit;
