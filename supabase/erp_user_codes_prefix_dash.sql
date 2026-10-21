-- Convert ERP user codes to readable abbreviated codes such as USR-6.
begin;
do $$
declare
  v_data_type text;
begin
  select data_type into v_data_type
  from information_schema.columns
  where table_schema='public' and table_name='erp_users' and column_name='user_code';
  if v_data_type is not null and v_data_type <> 'text' then
    alter table public.erp_users alter column user_code drop identity if exists;
    alter table public.erp_users alter column user_code type text
      using (case when user_code::text ~ '^[0-9]+$'
        then 'USR-' || user_code::text else user_code::text end);
  end if;
end $$;
update public.erp_users
set user_code='USR-' || user_code
where user_code ~ '^[0-9]+$';
create sequence if not exists public.erp_users_user_code_seq;
select setval(
  'public.erp_users_user_code_seq',
  greatest(coalesce((select max((substring(user_code from '^USR-([0-9]+)$'))::bigint
    ) from public.erp_users),0),1),
  true
);
create or replace function public.erp_assign_user_code()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.user_code is null or btrim(new.user_code) = '' then
    new.user_code := 'USR-' || nextval('public.erp_users_user_code_seq')::text;
  end if;
  return new;
end;
$$;
drop trigger if exists erp_users_assign_user_code on public.erp_users;
create trigger erp_users_assign_user_code
before insert on public.erp_users
for each row execute function public.erp_assign_user_code();
commit;
