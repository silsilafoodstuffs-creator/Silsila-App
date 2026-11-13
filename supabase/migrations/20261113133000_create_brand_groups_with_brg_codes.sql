CREATE TABLE IF NOT EXISTS public.erp_brand_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.erp_companies(id) ON DELETE CASCADE,
  group_code text NOT NULL,
  group_name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT erp_brand_groups_company_code_key UNIQUE(company_id, group_code),
  CONSTRAINT erp_brand_groups_code_format CHECK (group_code ~ '^Brg[0-9]{2}$')
);
CREATE INDEX IF NOT EXISTS erp_brand_groups_company_name_idx ON public.erp_brand_groups(company_id, group_name);
ALTER TABLE public.erp_brand_groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS erp_brand_groups_company_access ON public.erp_brand_groups;
CREATE POLICY erp_brand_groups_company_access ON public.erp_brand_groups FOR ALL TO authenticated
USING (public.erp_user_can_access_company(company_id))
WITH CHECK (public.erp_user_can_access_company(company_id));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.erp_brand_groups TO authenticated;
ALTER TABLE public.erp_brands ADD COLUMN IF NOT EXISTS brand_group_id uuid;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='erp_brands_brand_group_fk') THEN
  ALTER TABLE public.erp_brands ADD CONSTRAINT erp_brands_brand_group_fk FOREIGN KEY (brand_group_id) REFERENCES public.erp_brand_groups(id) ON DELETE SET NULL;
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS erp_brands_company_group_code_idx ON public.erp_brands(company_id, brand_group_id, brand_code);
CREATE OR REPLACE FUNCTION public.erp_assign_brand_group_code()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_prefix text; v_digits integer; v_max bigint;
BEGIN
 IF nullif(NEW.group_code,'') IS NOT NULL THEN RETURN NEW; END IF;
 SELECT prefix,digits INTO v_prefix,v_digits FROM public.erp_code_policy_config(NEW.company_id,'brand_group','Brg',2);
 IF v_prefix <> 'Brg' OR v_digits <> 2 THEN RAISE EXCEPTION 'سياسة كود مجموعات البراندات ثابتة على Brg ورقمين'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(NEW.company_id::text || ':brand_group:Brg',0));
 SELECT coalesce(max(substring(group_code from '^Brg([0-9]{2})$')::bigint),0) INTO v_max
 FROM public.erp_brand_groups WHERE company_id=NEW.company_id AND group_code ~ '^Brg[0-9]{2}$';
 IF v_max >= 99 THEN RAISE EXCEPTION 'انتهت أكواد مجموعات البراندات المتاحة (Brg99)'; END IF;
 NEW.group_code := 'Brg' || lpad((v_max+1)::text,2,'0'); RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS erp_brand_groups_assign_code ON public.erp_brand_groups;
CREATE TRIGGER erp_brand_groups_assign_code BEFORE INSERT ON public.erp_brand_groups FOR EACH ROW EXECUTE FUNCTION public.erp_assign_brand_group_code();
DROP TRIGGER IF EXISTS erp_brand_groups_updated_at ON public.erp_brand_groups;
CREATE TRIGGER erp_brand_groups_updated_at BEFORE UPDATE ON public.erp_brand_groups FOR EACH ROW EXECUTE FUNCTION public.erp_set_updated_at();
CREATE OR REPLACE FUNCTION public.erp_code_policy_lock_status(p_company_id uuid)
RETURNS text[] LANGUAGE sql SET search_path TO ''
AS $$
 SELECT array_cat(
  CASE WHEN EXISTS (SELECT 1 FROM public.erp_brands b WHERE b.company_id=p_company_id AND nullif(b.brand_code,'') IS NOT NULL)
   THEN array_append(private.erp_code_policy_lock_status(p_company_id),'brand_code')
   ELSE private.erp_code_policy_lock_status(p_company_id) END,
  CASE WHEN EXISTS (SELECT 1 FROM public.erp_brand_groups g WHERE g.company_id=p_company_id AND nullif(g.group_code,'') IS NOT NULL)
   THEN ARRAY['code_type.brand_group']::text[] ELSE ARRAY[]::text[] END
 );
$$;
UPDATE public.erp_program_policies p
SET policy_value=jsonb_set(coalesce(p.policy_value::jsonb,'{}'::jsonb),'{types,brand_group}',
 '{"prefix":"Brg","digits":2,"automatic":true,"composite":false,"enabled":true,"apply_to_all":true}'::jsonb,true)::text,
 updated_at=now()
WHERE p.policy_key='code_generation_registry';
