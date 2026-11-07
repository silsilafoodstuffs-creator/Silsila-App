begin;

-- Add an explicit active-company-membership requirement to every HR policy
-- that grants access based on the member's HR job title.
do $block$
declare
  policy_row record;
  next_using text;
  next_check text;
  alter_sql text;
begin
  for policy_row in
    select tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (
        tablename = 'erp_employees'
        or tablename like 'erp_hr_%'
        or tablename in (
          'erp_attendance_records',
          'erp_employee_documents',
          'erp_leave_requests',
          'erp_payroll_runs',
          'erp_payroll_lines'
        )
      )
      and (
        coalesce(qual, '') ilike '%erp_company_member_profiles%'
        or coalesce(with_check, '') ilike '%erp_company_member_profiles%'
      )
  loop
    next_using := policy_row.qual;
    next_check := policy_row.with_check;

    if next_using is not null
       and next_using not ilike '%erp_user_can_access_company%' then
      next_using := format(
        '(%s) AND public.erp_user_can_access_company(company_id)',
        next_using
      );
    end if;

    if next_check is not null
       and next_check not ilike '%erp_user_can_access_company%' then
      next_check := format(
        '(%s) AND public.erp_user_can_access_company(company_id)',
        next_check
      );
    end if;

    alter_sql := format(
      'ALTER POLICY %I ON public.%I',
      policy_row.policyname,
      policy_row.tablename
    );

    if next_using is not null then
      alter_sql := alter_sql || format(' USING (%s)', next_using);
    end if;

    if next_check is not null then
      alter_sql := alter_sql || format(' WITH CHECK (%s)', next_check);
    end if;

    execute alter_sql;
  end loop;
end;
$block$;

create or replace function public.erp_user_can_access_company(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = 'off'
as $function$
  select p_company_id is not null and exists (
    select 1
    from public.erp_company_members m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
  );
$function$;

create or replace function public.erp_user_has_company_role(
  p_company_id uuid,
  p_allowed_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = 'off'
as $function$
  select p_company_id is not null
    and coalesce(array_length(p_allowed_roles, 1), 0) > 0
    and exists (
      select 1
      from public.erp_company_members m
      where m.company_id = p_company_id
        and m.user_id = (select auth.uid())
        and m.is_active = true
        and m.member_role = any(p_allowed_roles)
    );
$function$;

commit;
