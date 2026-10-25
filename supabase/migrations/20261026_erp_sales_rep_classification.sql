alter table public.erp_sales_representatives add column if not exists rep_classification text not null default 'خارجي';
alter table public.erp_sales_representatives drop constraint if exists erp_sales_representatives_rep_classification_check;
alter table public.erp_sales_representatives add constraint erp_sales_representatives_rep_classification_check check (rep_classification in ('داخلي','خارجي','كول سنتر','مبيعات ميدانية','مبيعات هاتفية','أخرى'));
