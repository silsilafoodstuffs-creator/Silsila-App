-- Server-side enforcement for sales document-chain policies and optional invoice audit.
create or replace function public.erp_program_policy_applies(
  p_company_id uuid, p_policy_key text, p_actor_id uuid
) returns boolean
language plpgsql stable security definer set search_path=public
as $$
declare
  v_enabled boolean;
  v_all boolean;
  v_users jsonb;
  v_erp_user_id uuid;
begin
  select is_enabled, apply_to_all, user_ids
    into v_enabled, v_all, v_users
  from public.erp_program_policies
  where company_id=p_company_id and policy_key=p_policy_key
  limit 1;
  if not found then
    return p_policy_key='skip_quotation';
  end if;
  if not coalesce(v_enabled,false) then return false; end if;
  if coalesce(v_all,false) then return true; end if;
  if p_actor_id is null then return false; end if;
  select id into v_erp_user_id from public.erp_users
    where company_id=p_company_id and auth_user_id=p_actor_id and is_active=true limit 1;
  if v_erp_user_id is null then return false; end if;
  return coalesce(v_users,'[]'::jsonb) ? v_erp_user_id::text;
end;
$$;

create or replace function public.erp_enforce_sales_document_chain_policy()
returns trigger language plpgsql security definer set search_path=public
as $$
declare
  v_key text;
begin
  if new.document_type='order' then
    v_key := 'skip_quotation';
  elsif new.document_type='invoice' then
    v_key := 'skip_sales_order';
  else
    return new;
  end if;
  if coalesce(cardinality(new.source_document_ids),0)=0
     and not public.erp_program_policy_applies(new.company_id,v_key,auth.uid()) then
    if v_key='skip_quotation' then
      raise exception 'يجب ربط أمر البيع بعرض سعر؛ سياسة تخطي عرض الأسعار غير مفعلة لهذا المستخدم.';
    else
      raise exception 'يجب ربط فاتورة البيع بأمر بيع؛ سياسة تخطي أمر البيع غير مفعلة لهذا المستخدم.';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists erp_sales_document_chain_policy_guard on public.erp_sales_documents;
create trigger erp_sales_document_chain_policy_guard
before insert or update of document_type, source_document_ids, company_id
on public.erp_sales_documents for each row
execute function public.erp_enforce_sales_document_chain_policy();

create table if not exists public.erp_sales_invoice_audit_log (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete cascade,
  document_id uuid references public.erp_sales_documents(id) on delete set null,
  entity_table text not null,
  entity_id uuid,
  action text not null check(action in ('INSERT','UPDATE','DELETE')),
  actor_id uuid,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);
create index if not exists erp_sales_invoice_audit_company_doc_date_idx
 on public.erp_sales_invoice_audit_log(company_id,document_id,created_at desc);
alter table public.erp_sales_invoice_audit_log enable row level security;
drop policy if exists erp_sales_invoice_audit_member_read on public.erp_sales_invoice_audit_log;
create policy erp_sales_invoice_audit_member_read on public.erp_sales_invoice_audit_log
 for select to authenticated using (exists (
   select 1 from public.erp_company_members m
   where m.company_id=erp_sales_invoice_audit_log.company_id and m.user_id=auth.uid() and m.is_active=true
 ));

create or replace function public.erp_capture_sales_invoice_audit()
returns trigger language plpgsql security definer set search_path=public
as $$
declare
  v_row jsonb;
  v_company uuid;
  v_doc_id uuid;
  v_entity_id uuid;
  v_doc_type text;
  v_before jsonb;
  v_after jsonb;
begin
  if tg_op='DELETE' then v_row:=to_jsonb(old); else v_row:=to_jsonb(new); end if;
  if tg_table_name='erp_sales_documents' then
    v_company := (v_row->>'company_id')::uuid;
    v_doc_id := (v_row->>'id')::uuid;
    v_entity_id := v_doc_id;
    v_doc_type := v_row->>'document_type';
    if v_doc_type <> 'invoice' then
      if tg_op='DELETE' then return old; else return new; end if;
    end if;
    if tg_op='DELETE' then v_before:=to_jsonb(old); else v_before:=null; end if;
    if tg_op='INSERT' then v_after:=to_jsonb(new); elsif tg_op='UPDATE' then v_before:=to_jsonb(old); v_after:=to_jsonb(new); end if;
  else
    v_entity_id := (v_row->>'id')::uuid;
    v_doc_id := (v_row->>'document_id')::uuid;
    select d.company_id,d.document_type into v_company,v_doc_type
      from public.erp_sales_documents d where d.id=v_doc_id;
    if v_doc_type <> 'invoice' then
      if tg_op='DELETE' then return old; else return new; end if;
    end if;
    if tg_op='DELETE' then v_before:=to_jsonb(old); else v_before:=null; end if;
    if tg_op='INSERT' then v_after:=to_jsonb(new); elsif tg_op='UPDATE' then v_before:=to_jsonb(old); v_after:=to_jsonb(new); end if;
  end if;
  if public.erp_program_policy_applies(v_company,'sales_invoice_audit',auth.uid()) then
    insert into public.erp_sales_invoice_audit_log(company_id,document_id,entity_table,entity_id,action,actor_id,before_data,after_data)
    values(v_company,v_doc_id,tg_table_name,v_entity_id,tg_op,auth.uid(),v_before,v_after);
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;
drop trigger if exists erp_sales_invoice_audit_document_trigger on public.erp_sales_documents;
create trigger erp_sales_invoice_audit_document_trigger
after insert or update or delete on public.erp_sales_documents
for each row execute function public.erp_capture_sales_invoice_audit();
drop trigger if exists erp_sales_invoice_audit_line_trigger on public.erp_sales_lines;
create trigger erp_sales_invoice_audit_line_trigger
after insert or update or delete on public.erp_sales_lines
for each row execute function public.erp_capture_sales_invoice_audit();
