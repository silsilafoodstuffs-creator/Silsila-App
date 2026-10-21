-- Repair missing ERP program settings, customer-app user settings, and executive metrics RPC.
-- Safe to re-run; does not alter existing business records.

create table if not exists public.erp_program_settings (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null unique references public.erp_companies(id) on delete cascade,
 program_name varchar(150) not null default 'سلسلة',
 language_code varchar(10) not null default 'ar',
 logo_base64 text,
 logo_mime_type varchar(80),
 identity_primary_color varchar(9) not null default '#3E007D',
 identity_secondary_color varchar(9) not null default '#FFA015',
 identity_accent_color varchar(9) not null default '#FF27C3',
 identity_background_color varchar(9) not null default '#FFFFFF',
 heading_styles jsonb not null default '[]'::jsonb,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id)
);
alter table public.erp_program_settings enable row level security;
drop policy if exists erp_program_settings_member_select on public.erp_program_settings;
create policy erp_program_settings_member_select on public.erp_program_settings for select to authenticated using (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_program_settings.company_id and m.user_id=auth.uid() and m.is_active=true));
drop policy if exists erp_program_settings_member_insert on public.erp_program_settings;
create policy erp_program_settings_member_insert on public.erp_program_settings for insert to authenticated with check (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_program_settings.company_id and m.user_id=auth.uid() and m.is_active=true));
drop policy if exists erp_program_settings_member_update on public.erp_program_settings;
create policy erp_program_settings_member_update on public.erp_program_settings for update to authenticated using (
 exists(select 1 from public.erp_company_members m where m.company_id=erp_program_settings.company_id and m.user_id=auth.uid() and m.is_active=true))
 with check (exists(select 1 from public.erp_company_members m where m.company_id=erp_program_settings.company_id and m.user_id=auth.uid() and m.is_active=true));
grant select,insert,update on public.erp_program_settings to authenticated;

create table if not exists public.user_settings (
 user_id uuid primary key references auth.users(id) on delete cascade,
 language text not null default 'ar' check (language in ('ar','en')),
 notifications_enabled boolean not null default true,
 offers_notifications boolean not null default true,
 order_notifications boolean not null default true,
 price_display text not null default 'final' check (price_display in ('final','negotiable')),
 theme text not null default 'light' check (theme in ('light','dark','system')),
 updated_at timestamptz not null default now()
);
alter table public.user_settings enable row level security;
drop policy if exists user_settings_select_own on public.user_settings;
create policy user_settings_select_own on public.user_settings for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists user_settings_insert_own on public.user_settings;
create policy user_settings_insert_own on public.user_settings for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists user_settings_update_own on public.user_settings;
create policy user_settings_update_own on public.user_settings for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant select,insert,update on public.user_settings to authenticated;

create or replace function public.erp_get_executive_metrics(
 p_company_id uuid,
 p_month_start date default date_trunc('month', current_date)::date,
 p_month_end date default (date_trunc('month', current_date) + interval '1 month')::date
)
returns jsonb language plpgsql stable security definer
set search_path = public set row_security = off
as $$
declare v_result jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not public.erp_user_can_access_company(p_company_id) then raise exception 'You do not have access to this company'; end if;
 if p_month_end <= p_month_start then raise exception 'Month end must be after month start'; end if;
 with
 sales as (
  select d.* from public.erp_sales_documents d
  where d.company_id=p_company_id and d.status='posted' and d.is_demo_data=false
    and d.document_date>=p_month_start and d.document_date<p_month_end
 ),
 purchase_totals as (
  select coalesce(sum(case when d.document_type='return' then -d.grand_total else d.grand_total end),0) total
  from public.erp_purchase_documents d
  where d.company_id=p_company_id and d.status='posted' and d.is_demo_data=false
    and d.document_date>=p_month_start and d.document_date<p_month_end
 ),
 sales_totals as (
  select coalesce(sum(case when document_type='return' then -grand_total else grand_total end),0) sales,
   coalesce(sum(case when document_type='return' then -paid_total else paid_total end),0) collections,
   coalesce(sum(case when document_type='invoice' then greatest(grand_total-paid_total,0) else 0 end),0) receivables
  from sales
 ),
 margin_totals as (
  select coalesce(sum((case when d.document_type='return' then -1 else 1 end)*(l.line_total-l.quantity*i.purchase_price)),0) gross_profit
  from sales d join public.erp_sales_lines l on l.document_id=d.id
  join public.erp_items i on i.id=l.item_id and i.company_id=p_company_id
 ),
 days as (select generate_series(current_date-6,current_date,interval '1 day')::date as calendar_day),
 daily as (
  select d.document_date as calendar_day,
   coalesce(sum(case when d.document_type='return' then -d.grand_total else d.grand_total end),0) sales,
   coalesce(sum(case when d.document_type='return' then -d.paid_total else d.paid_total end),0) collections
  from public.erp_sales_documents d
  where d.company_id=p_company_id and d.status='posted' and d.is_demo_data=false
   and d.document_date>=current_date-6 and d.document_date<=current_date
  group by d.document_date
 ),
 inventory_by_group as (
  select coalesce(g.group_name,'غير مصنف') group_name,
   sum((m.quantity_in-m.quantity_out)*i.purchase_price) value
  from public.erp_inventory_movements m
  join public.erp_items i on i.id=m.item_id and i.company_id=p_company_id
  left join public.erp_item_groups g on g.id=i.group_id and g.company_id=p_company_id
  where m.company_id=p_company_id
  group by coalesce(g.group_name,'غير مصنف')
  order by sum((m.quantity_in-m.quantity_out)*i.purchase_price) desc limit 7
 ),
 inventory_total as (
  select coalesce(sum((m.quantity_in-m.quantity_out)*i.purchase_price),0) value
  from public.erp_inventory_movements m join public.erp_items i on i.id=m.item_id and i.company_id=p_company_id
  where m.company_id=p_company_id
 )
 select jsonb_build_object(
  'month_start',p_month_start,'month_end_exclusive',p_month_end,
  'sales',st.sales,'collections',st.collections,'receivables',st.receivables,
  'purchases',pt.total,'gross_profit_estimate',mt.gross_profit,'inventory_value_estimate',it.value,
  'daily_sales',coalesce((select jsonb_agg(coalesce(d.sales,0) order by days.calendar_day) from days left join daily d on d.calendar_day=days.calendar_day),'[]'::jsonb),
  'daily_collections',coalesce((select jsonb_agg(coalesce(d.collections,0) order by days.calendar_day) from days left join daily d on d.calendar_day=days.calendar_day),'[]'::jsonb),
  'inventory_group_labels',coalesce((select jsonb_agg(group_name order by value desc) from inventory_by_group),'[]'::jsonb),
  'inventory_group_values',coalesce((select jsonb_agg(value order by value desc) from inventory_by_group),'[]'::jsonb)
 ) into v_result from sales_totals st cross join purchase_totals pt cross join margin_totals mt cross join inventory_total it;
 return v_result;
end;
$$;
revoke all on function public.erp_get_executive_metrics(uuid,date,date) from public, anon;
grant execute on function public.erp_get_executive_metrics(uuid,date,date) to authenticated;
notify pgrst, 'reload schema';
