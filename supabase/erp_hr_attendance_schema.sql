-- Silsila HR attendance, shift rules, and fingerprint devices.
-- Apply after supabase/erp_schema.sql. Review tenant policies before deployment.
-- RLS stays closed to client roles; real device polling must run from a trusted service.

create table if not exists public.erp_hr_shifts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  shift_code text not null,
  shift_name text not null,
  start_time time not null,
  end_time time not null,
  crosses_midnight boolean generated always as (end_time <= start_time) stored,
  weekly_holidays integer[] not null default '{}',
  grace_rules jsonb not null default '{"arrival_minutes":10,"departure_minutes":10,"monthly_minutes":60,"overrun_multiplier":1}'::jsonb,
  attendance_rules jsonb not null default '{}'::jsonb,
  late_intervals jsonb not null default '[
    {"level":1,"from_minute":1,"to_minute":10,"minute_value":1,"calculation":"deduction"},
    {"level":2,"from_minute":11,"to_minute":20,"minute_value":1,"calculation":"deduction"},
    {"level":3,"from_minute":21,"to_minute":30,"minute_value":1,"calculation":"deduction"},
    {"level":4,"from_minute":31,"to_minute":40,"minute_value":1,"calculation":"deduction"},
    {"level":5,"from_minute":41,"to_minute":999,"minute_value":1,"calculation":"deduction"}
  ]'::jsonb,
  missed_punch_rules jsonb not null default '{"arrival":1,"departure":1,"whole_day":1}'::jsonb,
  absence_rules jsonb not null default '{"excused_1":0,"excused_2":0,"excused_3_plus":0,"unexcused_1":1,"unexcused_2":1,"unexcused_3_plus":1,"sick":0,"work_injury":0}'::jsonb,
  leave_rules jsonb not null default '{"weekly_overtime_value":1,"public_overtime_value":1,"annual_overtime_value":1}'::jsonb,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, shift_code),
  check (array_position(weekly_holidays, 0) is null and array_position(weekly_holidays, 8) is null)
);

create table if not exists public.erp_hr_shift_assignments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  shift_id uuid not null references public.erp_hr_shifts(id) on delete cascade,
  employee_id uuid not null,
  department_code text,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  effective_from date not null default current_date,
  effective_to date,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from),
  unique(shift_id, employee_id, effective_from)
);

create table if not exists public.erp_hr_fingerprint_devices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  branch_id uuid references public.erp_branches(id) on delete restrict,
  device_name text not null,
  manufacturer text,
  model text,
  protocol text,
  connection_type text not null check(connection_type in ('ip','usb','gateway')),
  ip_address inet,
  port integer check(port between 1 and 65535),
  usb_device_id text,
  status text not null default 'disconnected' check(status in ('connected','disconnected','error','disabled')),
  last_seen_at timestamptz,
  last_sync_at timestamptz,
  last_error text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (connection_type = 'ip' and ip_address is not null and port is not null)
    or (connection_type = 'usb' and coalesce(usb_device_id,'') <> '')
    or connection_type = 'gateway'
  )
);

create table if not exists public.erp_hr_attendance_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.erp_companies(id) on delete restrict,
  device_id uuid references public.erp_hr_fingerprint_devices(id) on delete set null,
  employee_code text not null,
  employee_id uuid,
  event_at timestamptz not null,
  event_type text not null default 'unknown' check(event_type in ('check_in','check_out','break_in','break_out','unknown')),
  source_event_id text,
  source_payload jsonb not null default '{}'::jsonb,
  import_method text not null check(import_method in ('ip','usb','gateway','manual','file')),
  imported_at timestamptz not null default now(),
  processing_status text not null default 'pending' check(processing_status in ('pending','processed','duplicate','error')),
  processing_note text,
  unique(device_id, source_event_id)
);

create index if not exists erp_hr_shifts_company_active_idx on public.erp_hr_shifts(company_id, is_active);
create index if not exists erp_hr_assignments_employee_dates_idx on public.erp_hr_shift_assignments(company_id, employee_id, effective_from, effective_to);
create index if not exists erp_hr_devices_company_status_idx on public.erp_hr_fingerprint_devices(company_id, status);
create index if not exists erp_hr_attendance_events_company_time_idx on public.erp_hr_attendance_events(company_id, event_at desc);
create index if not exists erp_hr_attendance_events_employee_time_idx on public.erp_hr_attendance_events(company_id, employee_code, event_at);

alter table public.erp_hr_shifts enable row level security;
alter table public.erp_hr_shift_assignments enable row level security;
alter table public.erp_hr_fingerprint_devices enable row level security;
alter table public.erp_hr_attendance_events enable row level security;

drop trigger if exists erp_hr_shifts_updated_at on public.erp_hr_shifts;
create trigger erp_hr_shifts_updated_at before update on public.erp_hr_shifts
for each row execute function public.erp_set_updated_at();

drop trigger if exists erp_hr_devices_updated_at on public.erp_hr_fingerprint_devices;
create trigger erp_hr_devices_updated_at before update on public.erp_hr_fingerprint_devices
for each row execute function public.erp_set_updated_at();

comment on table public.erp_hr_attendance_events is
'Raw imported fingerprint events. Keep raw events immutable; deduplicate by device and source_event_id and process attendance separately.';
comment on table public.erp_hr_fingerprint_devices is
'Device configuration and last confirmed status. A status must only be marked connected after a real protocol handshake.';
comment on table public.erp_hr_shifts is
'HR shift schedule and versioned policy JSON. Validate late intervals for contiguous non-overlapping ranges in trusted backend before activation.';
