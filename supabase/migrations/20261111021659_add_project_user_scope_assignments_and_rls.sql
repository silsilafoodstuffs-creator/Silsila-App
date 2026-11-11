CREATE TABLE IF NOT EXISTS public.erp_user_project_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.erp_companies(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES public.erp_construction_projects(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.erp_users(id) ON DELETE CASCADE,
  is_allowed boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT erp_user_project_access_unique UNIQUE(company_id,project_id,user_id)
);
CREATE INDEX IF NOT EXISTS erp_user_project_access_user_idx
  ON public.erp_user_project_access(company_id,user_id) WHERE is_allowed;
CREATE INDEX IF NOT EXISTS erp_user_project_access_project_idx
  ON public.erp_user_project_access(company_id,project_id) WHERE is_allowed;
ALTER TABLE public.erp_user_project_access ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.erp_user_project_access FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.erp_user_can_access_project_scope(
  p_company_id uuid, p_project_id uuid
) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR p_company_id IS NULL OR p_project_id IS NULL THEN RETURN false; END IF;
  IF public.erp_user_has_company_role(p_company_id, ARRAY['owner','admin']::text[]) THEN RETURN true; END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.erp_users u
    JOIN public.erp_user_project_access a ON a.user_id=u.id AND a.company_id=u.company_id
    JOIN public.erp_construction_projects p ON p.id=a.project_id AND p.company_id=a.company_id
    WHERE u.company_id=p_company_id AND u.auth_user_id=auth.uid() AND u.is_active=true
      AND a.project_id=p_project_id AND a.is_allowed=true
  );
END;
$$;
REVOKE ALL ON FUNCTION public.erp_user_can_access_project_scope(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_user_can_access_project_scope(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.erp_replace_user_project_access(
  p_company_id uuid, p_user_id uuid, p_access jsonb
) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' SET row_security = off
AS $$
DECLARE v_count integer;
BEGIN
  IF auth.uid() IS NULL OR NOT public.erp_user_has_company_role(p_company_id, ARRAY['owner','admin','manager']::text[]) THEN
    RAISE EXCEPTION 'غير مصرح بإدارة تخصيصات المشروعات';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.erp_users u WHERE u.id=p_user_id AND u.company_id=p_company_id AND u.is_active=true) THEN
    RAISE EXCEPTION 'المستخدم المستهدف غير نشط أو لا يتبع الشركة';
  END IF;
  IF p_access IS NULL OR jsonb_typeof(p_access) <> 'array' THEN RAISE EXCEPTION 'قائمة تخصيصات المشروعات غير صحيحة'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_access) x WHERE nullif(x->>'project_id','') IS NULL) THEN
    RAISE EXCEPTION 'كل تخصيص يجب أن يحتوي project_id';
  END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_access)) <> (SELECT count(DISTINCT x->>'project_id') FROM jsonb_array_elements(p_access) x) THEN
    RAISE EXCEPTION 'يوجد مشروع مكرر في التخصيصات';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_access) x
    LEFT JOIN public.erp_construction_projects p ON p.id=(x->>'project_id')::uuid AND p.company_id=p_company_id
    WHERE p.id IS NULL
  ) THEN RAISE EXCEPTION 'يوجد مشروع غير تابع للشركة'; END IF;
  DELETE FROM public.erp_user_project_access WHERE company_id=p_company_id AND user_id=p_user_id;
  INSERT INTO public.erp_user_project_access(company_id,project_id,user_id,is_allowed,created_by)
  SELECT p_company_id,(x->>'project_id')::uuid,p_user_id,coalesce((x->>'is_allowed')::boolean,true),auth.uid()
  FROM jsonb_array_elements(p_access) x;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.erp_replace_user_project_access(uuid,uuid,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_replace_user_project_access(uuid,uuid,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.erp_seed_project_creator_access()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' SET row_security = off
AS $$
DECLARE v_user_id uuid;
BEGIN
  SELECT u.id INTO v_user_id FROM public.erp_users u
  WHERE u.company_id=NEW.company_id AND u.auth_user_id=auth.uid() AND u.is_active=true LIMIT 1;
  IF v_user_id IS NOT NULL THEN
    INSERT INTO public.erp_user_project_access(company_id,project_id,user_id,is_allowed,created_by)
    VALUES(NEW.company_id,NEW.id,v_user_id,true,auth.uid())
    ON CONFLICT(company_id,project_id,user_id) DO UPDATE SET is_allowed=true,updated_at=now();
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.erp_seed_project_creator_access() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS erp_seed_project_creator_access ON public.erp_construction_projects;
CREATE TRIGGER erp_seed_project_creator_access AFTER INSERT ON public.erp_construction_projects
FOR EACH ROW EXECUTE FUNCTION public.erp_seed_project_creator_access();

DROP POLICY IF EXISTS erp_project_scope_select ON public.erp_construction_projects;
CREATE POLICY erp_project_scope_select ON public.erp_construction_projects AS RESTRICTIVE FOR SELECT TO authenticated
USING (public.erp_user_can_access_project_scope(company_id,id));
DROP POLICY IF EXISTS erp_project_scope_insert ON public.erp_construction_projects;
CREATE POLICY erp_project_scope_insert ON public.erp_construction_projects AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (public.erp_user_has_company_role(company_id,ARRAY['owner','admin','manager']::text[]));
DROP POLICY IF EXISTS erp_project_scope_update ON public.erp_construction_projects;
CREATE POLICY erp_project_scope_update ON public.erp_construction_projects AS RESTRICTIVE FOR UPDATE TO authenticated
USING (public.erp_user_can_access_project_scope(company_id,id))
WITH CHECK (public.erp_user_can_access_project_scope(company_id,id));
DROP POLICY IF EXISTS erp_project_scope_delete ON public.erp_construction_projects;
CREATE POLICY erp_project_scope_delete ON public.erp_construction_projects AS RESTRICTIVE FOR DELETE TO authenticated
USING (public.erp_user_can_access_project_scope(company_id,id));

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.table_name FROM information_schema.columns c
    JOIN pg_class pc ON pc.relname=c.table_name
    JOIN pg_namespace pn ON pn.oid=pc.relnamespace AND pn.nspname='public'
    WHERE c.table_schema='public' AND c.column_name='project_id' AND pc.relkind IN ('r','p')
      AND EXISTS (SELECT 1 FROM information_schema.columns co WHERE co.table_schema='public' AND co.table_name=c.table_name AND co.column_name='company_id')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I','erp_project_scope_'||r.table_name,r.table_name);
    EXECUTE format('CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (project_id IS NOT NULL AND public.erp_user_can_access_project_scope(company_id,project_id)) WITH CHECK (project_id IS NOT NULL AND public.erp_user_can_access_project_scope(company_id,project_id))','erp_project_scope_'||r.table_name,r.table_name);
  END LOOP;
END;
$$;

DROP POLICY IF EXISTS erp_project_scope_erp_construction_certificate_lines ON public.erp_construction_certificate_lines;
CREATE POLICY erp_project_scope_erp_construction_certificate_lines ON public.erp_construction_certificate_lines
AS RESTRICTIVE FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.erp_construction_payment_certificates c WHERE c.id=erp_construction_certificate_lines.certificate_id AND c.company_id=erp_construction_certificate_lines.company_id AND public.erp_user_can_access_project_scope(c.company_id,c.project_id)))
WITH CHECK (EXISTS (SELECT 1 FROM public.erp_construction_payment_certificates c WHERE c.id=erp_construction_certificate_lines.certificate_id AND c.company_id=erp_construction_certificate_lines.company_id AND public.erp_user_can_access_project_scope(c.company_id,c.project_id)));

DROP POLICY IF EXISTS erp_project_scope_erp_construction_material_request_lines ON public.erp_construction_material_request_lines;
CREATE POLICY erp_project_scope_erp_construction_material_request_lines ON public.erp_construction_material_request_lines
AS RESTRICTIVE FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.erp_construction_material_requests r WHERE r.id=erp_construction_material_request_lines.request_id AND r.company_id=erp_construction_material_request_lines.company_id AND public.erp_user_can_access_project_scope(r.company_id,r.project_id)))
WITH CHECK (EXISTS (SELECT 1 FROM public.erp_construction_material_requests r WHERE r.id=erp_construction_material_request_lines.request_id AND r.company_id=erp_construction_material_request_lines.company_id AND public.erp_user_can_access_project_scope(r.company_id,r.project_id)));
