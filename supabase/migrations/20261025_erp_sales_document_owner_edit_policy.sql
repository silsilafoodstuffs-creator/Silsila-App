-- Enforce the sales-document ownership policy at the database boundary.
-- A user may edit another user's sales document only when the policy applies to them.
create or replace function public.erp_guard_sales_document_owner_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Trusted server-side/service-role operations do not carry an end-user JWT.
  if auth.uid() is null then
    return new;
  end if;

  -- Legacy documents without an owner cannot be reliably attributed.
  if old.created_by is not null
     and old.created_by is distinct from auth.uid()
     and not public.erp_program_policy_applies(
       old.company_id,
       'edit_other_user_document',
       auth.uid()
     ) then
    raise exception 'لا يمكن تعديل مستند أنشأه مستخدم آخر؛ سياسة السماح بالتعديل غير مفعلة لهذا المستخدم.'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists erp_sales_document_owner_edit_guard on public.erp_sales_documents;
create trigger erp_sales_document_owner_edit_guard
before update on public.erp_sales_documents
for each row
execute function public.erp_guard_sales_document_owner_edit();
