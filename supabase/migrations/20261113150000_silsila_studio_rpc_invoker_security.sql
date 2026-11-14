-- Run Studio mutations as the authenticated caller so table RLS remains authoritative.
begin;

alter function public.erp_studio_save_draft(uuid,uuid,text,text,text,integer,jsonb,jsonb,integer,text)
  security invoker;
alter function public.erp_studio_approve_design(uuid,uuid,integer)
  security invoker;
alter function public.erp_studio_publish_design(uuid,uuid,integer)
  security invoker;
alter function public.erp_studio_restore_version(uuid,uuid,integer,integer)
  security invoker;

alter function public.erp_studio_save_draft(uuid,uuid,text,text,text,integer,jsonb,jsonb,integer,text)
  reset row_security;
alter function public.erp_studio_approve_design(uuid,uuid,integer)
  reset row_security;
alter function public.erp_studio_publish_design(uuid,uuid,integer)
  reset row_security;
alter function public.erp_studio_restore_version(uuid,uuid,integer,integer)
  reset row_security;

-- These are the minimum table privileges needed by the RPCs. RLS policies
-- still restrict every write to owner/admin users within the same company.
grant insert, update on public.erp_studio_designs to authenticated;
grant insert on public.erp_studio_design_versions to authenticated;
grant insert on public.erp_studio_audit_log to authenticated;

commit;
