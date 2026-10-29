-- Link ERP users to optional classifications; keep existing user rows unchanged.
begin;
alter table public.erp_users
  add column if not exists classification_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.erp_users'::regclass
      and conname = 'erp_users_classification_id_fkey'
  ) then
    alter table public.erp_users
      add constraint erp_users_classification_id_fkey
      foreign key (classification_id)
      references public.erp_user_classifications(id)
      on delete set null;
  end if;
end $$;

create index if not exists erp_users_classification_idx
  on public.erp_users(company_id, classification_id);
commit;
