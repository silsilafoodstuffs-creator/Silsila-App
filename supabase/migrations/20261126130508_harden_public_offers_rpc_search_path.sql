-- This public SECURITY DEFINER RPC uses schema-qualified relations and
-- built-in PostgreSQL functions only. An empty search_path prevents object
-- shadowing while preserving its public active-offer feed.
ALTER FUNCTION public.get_targeted_active_offers(text, integer)
  SET search_path = '';
