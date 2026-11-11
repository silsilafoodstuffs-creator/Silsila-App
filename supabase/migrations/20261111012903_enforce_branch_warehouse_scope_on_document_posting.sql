create or replace function public.erp_enforce_document_post_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
begin
  if new.status = 'posted' and old.status is distinct from new.status and auth.uid() is not null then
    if not public.erp_user_can_access_warehouse_scope(new.company_id,new.branch_id,new.warehouse_id) then
      raise exception 'ليس لديك تصريح لترحيل مستند على هذا الفرع والمخزن' using errcode='42501';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.erp_enforce_document_post_scope() from public,anon,authenticated;
drop trigger if exists trg_erp_sales_document_post_scope on public.erp_sales_documents;
create trigger trg_erp_sales_document_post_scope before update of status on public.erp_sales_documents
for each row execute function public.erp_enforce_document_post_scope();
drop trigger if exists trg_erp_purchase_document_post_scope on public.erp_purchase_documents;
create trigger trg_erp_purchase_document_post_scope before update of status on public.erp_purchase_documents
for each row execute function public.erp_enforce_document_post_scope();
drop trigger if exists trg_erp_stocktake_post_scope on public.erp_stocktakes;
create trigger trg_erp_stocktake_post_scope before update of status on public.erp_stocktakes
for each row execute function public.erp_enforce_document_post_scope();
