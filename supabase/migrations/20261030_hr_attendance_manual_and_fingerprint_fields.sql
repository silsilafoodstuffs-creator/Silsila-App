-- Extend daily attendance with payroll-facing day fractions, absence reasons/penalties and source tracking.
begin;
alter table public.erp_attendance_records
  add column if not exists job_id uuid references public.erp_hr_jobs(id) on delete set null,
  add column if not exists attendance_fraction numeric(4,2) not null default 1,
  add column if not exists absence_type text,
  add column if not exists absence_penalty_days numeric(4,2) not null default 0,
  add column if not exists attendance_source text not null default 'manual';

create index if not exists erp_attendance_company_day_idx
  on public.erp_attendance_records(company_id, work_date);
create index if not exists erp_attendance_job_day_idx
  on public.erp_attendance_records(job_id, work_date);

comment on column public.erp_attendance_records.attendance_fraction is
  'Fraction of a paid workday credited for attendance, from 0 to 1.';
comment on column public.erp_attendance_records.absence_penalty_days is
  'Absence penalty in days, from 0 to 5; applies only to unauthorized absence.';
comment on column public.erp_attendance_records.attendance_source is
  'How attendance was recorded: manual, direct, or fingerprint.';
commit;
