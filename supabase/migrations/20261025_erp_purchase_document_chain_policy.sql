-- Preserve purchasing document lineage and enforce skip policies server-side.
alter table public.erp_purchase_documents
  add column if not exists source_document_ids uuid[] not null default '{}';

create index if not exists erp_purchase_documents_source_ids_gin
  on public.erp_purchase_documents using gin (source_document_ids);

create or replace function public.erp_enforce_purchase_document_chain_policy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
  v_source_type text;
  v_source_count integer;
  v_valid_count integer;
begin
  if new.document_type = 'order' then
    v_key := 'skip_supply_order';
    v_source_type := 'receipt';
  elsif new.document_type = 'invoice' then
    v_key := 'skip_purchase_order';
    v_source_type := 'order';
  else
    return new;
  end if;

  v_source_count := coalesce(cardinality(new.source_document_ids), 0);
  if v_source_count = 0 then
    if not public.erp_program_policy_applies(new.company_id, v_key, auth.uid()) then
      if v_key = 'skip_supply_order' then
        raise exception 'يجب ربط أمر الشراء بأمر توريد؛ سياسة تخطي أمر التوريد غير مفعلة لهذا المستخدم.';
      else
        raise exception 'يجب ربط فاتورة الشراء بأمر شراء؛ سياسة تخطي أمر الشراء غير مفعلة لهذا المستخدم.';
      end if;
    end if;
    return new;
  end if;

  select count(*) into v_valid_count
  from unnest(new.source_document_ids) source_id
  join public.erp_purchase_documents src
    on src.id = source_id
   and src.company_id = new.company_id
   and src.supplier_id = new.supplier_id
   and src.document_type = v_source_type
   and src.status in ('draft','approved','posted');

  if v_valid_count <> v_source_count then
    raise exception 'مستند المصدر غير صالح أو لا يتبع نفس الشركة والمورد أو نوع المستند المطلوب.';
  end if;
  return new;
end;
$$;

drop trigger if exists erp_purchase_document_chain_policy_guard on public.erp_purchase_documents;
create trigger erp_purchase_document_chain_policy_guard
before insert or update of document_type, source_document_ids, company_id, supplier_id
on public.erp_purchase_documents
for each row execute function public.erp_enforce_purchase_document_chain_policy();
