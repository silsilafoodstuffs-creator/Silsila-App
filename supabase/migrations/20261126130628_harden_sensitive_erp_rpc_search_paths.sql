-- Both selective-clear RPCs qualify their relations with public.* and use
-- PostgreSQL built-ins. An empty search_path prevents temporary/public object
-- shadowing in SECURITY DEFINER execution.
ALTER FUNCTION public.erp_prepare_selective_data_clear(uuid, text[])
  SET search_path = '';
ALTER FUNCTION public.erp_complete_selective_data_clear(uuid, text)
  SET search_path = '';
