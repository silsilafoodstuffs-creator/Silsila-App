-- Permission matrix must persist the same access flag used by the ERP UI.
-- Safe for databases where the base schema has already been applied.
begin;
alter table public.erp_user_permission_matrix
  add column if not exists can_access boolean not null default false;
comment on column public.erp_user_permission_matrix.can_access
  is 'Whether the user may access the menu, submenu, or page represented by this matrix row.';
commit;
