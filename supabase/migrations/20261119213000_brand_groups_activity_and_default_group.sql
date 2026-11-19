BEGIN;
ALTER TABLE public.erp_brand_groups ADD COLUMN IF NOT EXISTS activity_code text;
UPDATE public.erp_brand_groups SET activity_code='01' WHERE activity_code IS NULL OR btrim(activity_code)='';
ALTER TABLE public.erp_brand_groups ALTER COLUMN activity_code SET DEFAULT '01', ALTER COLUMN activity_code SET NOT NULL;
DO $$
DECLARE v_company uuid; v_old_group_id uuid; v_default_group_id uuid; v_soda_group_id uuid; v_brand_count bigint;
BEGIN
  FOR v_company IN
    SELECT DISTINCT company_id FROM public.erp_brand_groups
    UNION SELECT DISTINCT company_id FROM public.erp_brands
  LOOP
    SELECT id INTO v_old_group_id FROM public.erp_brand_groups
    WHERE company_id=v_company AND group_code='Brg01' AND lower(coalesce(group_name_en,''))='other' LIMIT 1;
    IF v_old_group_id IS NOT NULL THEN
      SELECT count(*) INTO v_brand_count FROM public.erp_brands WHERE company_id=v_company AND brand_group_id=v_old_group_id;
      IF v_brand_count>0 THEN
        RAISE EXCEPTION 'Cannot remove English Other brand group for company %: % brands still reference it',v_company,v_brand_count;
      END IF;
      DELETE FROM public.erp_brand_groups WHERE id=v_old_group_id AND company_id=v_company;
    END IF;
    SELECT id INTO v_default_group_id FROM public.erp_brand_groups
    WHERE company_id=v_company AND group_name='بدون مجموعة' ORDER BY group_code LIMIT 1;
    IF v_default_group_id IS NULL THEN
      INSERT INTO public.erp_brand_groups(company_id,group_code,group_name,group_name_en,activity_code,is_active,show_in_app)
      VALUES(v_company,'Brg01','بدون مجموعة',NULL,'01',true,true) RETURNING id INTO v_default_group_id;
    ELSE
      UPDATE public.erp_brand_groups SET group_code='Brg01',group_name='بدون مجموعة',group_name_en=NULL,
        activity_code='01',is_active=true,show_in_app=true WHERE id=v_default_group_id AND company_id=v_company;
    END IF;
    SELECT id INTO v_soda_group_id FROM public.erp_brand_groups
    WHERE company_id=v_company AND group_name='مشروبات غازية وطاقة ومياه' LIMIT 1;
    IF v_soda_group_id IS NOT NULL THEN
      UPDATE public.erp_brands SET brand_group_id=v_soda_group_id
      WHERE company_id=v_company AND brand_group_id IS NULL
        AND brand_group IN ('بيبسي وسفن وميراندا','كوكاكولا وسبرايت وفانتا');
    END IF;
    UPDATE public.erp_brands SET brand_group_id=v_default_group_id
      WHERE company_id=v_company AND brand_group_id IS NULL
        AND coalesce(btrim(brand_group),'')='';
    IF NOT EXISTS (SELECT 1 FROM public.erp_brand_groups WHERE company_id=v_company AND group_name='نشويات ارز ودقيق') THEN
      INSERT INTO public.erp_brand_groups(company_id,group_name,activity_code,is_active,show_in_app)
      VALUES(v_company,'نشويات ارز ودقيق','01',true,true);
    END IF;
  END LOOP;
END $$;
ALTER TABLE public.erp_brand_groups DROP CONSTRAINT IF EXISTS erp_brand_groups_activity_code_fkey;
ALTER TABLE public.erp_brand_groups ADD CONSTRAINT erp_brand_groups_activity_code_fkey
  FOREIGN KEY(activity_code) REFERENCES public.activity_types(code) ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS erp_brand_groups_company_activity_code_idx ON public.erp_brand_groups(company_id,activity_code,group_code);
COMMENT ON COLUMN public.erp_brand_groups.activity_code IS 'Canonical activity_types.code that owns this brand group.';
COMMIT;
