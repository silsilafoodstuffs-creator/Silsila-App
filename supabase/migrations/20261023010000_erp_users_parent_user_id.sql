-- Allow each ERP user to have one optional parent user.
-- Null parent_user_id means the user is a primary user under their user type.
alter table public.erp_users
  add column if not exists parent_user_id uuid null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'erp_users_parent_user_id_fkey'
      and conrelid = 'public.erp_users'::regclass
  ) then
    alter table public.erp_users
      add constraint erp_users_parent_user_id_fkey
      foreign key (parent_user_id) references public.erp_users(id)
      on delete set null;
  end if;
end $$;

create index if not exists idx_erp_users_company_type_parent
  on public.erp_users(company_id, user_type_id, parent_user_id);

comment on column public.erp_users.parent_user_id is
  'Optional parent ERP user for the user hierarchy. NULL means primary user under the selected user type.';
