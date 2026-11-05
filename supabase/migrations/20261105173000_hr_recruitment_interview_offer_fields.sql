alter table public.erp_hr_recruitment_candidates
  add column if not exists interview_date date,
  add column if not exists interview_result text,
  add column if not exists interview_notes text,
  add column if not exists offer_salary numeric(14,2),
  add column if not exists offer_issued_on date,
  add column if not exists offer_expires_on date,
  add column if not exists joining_date date;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='erp_hr_recruitment_offer_dates_check') then
    alter table public.erp_hr_recruitment_candidates
      add constraint erp_hr_recruitment_offer_dates_check
      check (offer_expires_on is null or offer_issued_on is null or offer_expires_on >= offer_issued_on);
  end if;
  if not exists (select 1 from pg_constraint where conname='erp_hr_recruitment_offer_salary_check') then
    alter table public.erp_hr_recruitment_candidates
      add constraint erp_hr_recruitment_offer_salary_check
      check (offer_salary is null or offer_salary >= 0);
  end if;
end $$;