-- Enforce referential integrity for customer-to-sales-representative links.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='erp_parties_sales_rep_id_fkey'
      and conrelid='public.erp_parties'::regclass
  ) then
    alter table public.erp_parties
      add constraint erp_parties_sales_rep_id_fkey
      foreign key (sales_rep_id)
      references public.erp_sales_representatives(id)
      on delete set null;
  end if;
end $$;

create index if not exists idx_erp_parties_company_sales_rep_id
  on public.erp_parties(company_id,sales_rep_id)
  where sales_rep_id is not null;
