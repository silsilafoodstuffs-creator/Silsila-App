-- Workspace audit history is append-only. Owners and delegated auditors may
-- read it and authorized users may append events, but no client may rewrite or
-- erase historical evidence.
drop policy if exists workspace_update on public.erp_business_workspace_audit_log;
drop policy if exists workspace_delete on public.erp_business_workspace_audit_log;

revoke update, delete, truncate
  on public.erp_business_workspace_audit_log
  from anon, authenticated;

grant select, insert
  on public.erp_business_workspace_audit_log
  to authenticated;
