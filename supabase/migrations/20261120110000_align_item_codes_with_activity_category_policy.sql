-- Align item codes with the complete inherited category code:
-- activity (2) + main (2) + sub (2) + secondary (2) + brand (4) + serial (3).
-- Activity and category identifiers already matching policy are preserved.

BEGIN;

DO $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef('public.erp_assign_item_hierarchical_code()'::regprocedure)
    INTO v_def;

  IF position(
    'length(v_category_digits)<>(v_main_digits+v_sub_digits+v_secondary_digits)'
    IN v_def
  ) > 0 THEN
    v_def := replace(
      v_def,
      'length(v_category_digits)<>(v_main_digits+v_sub_digits+v_secondary_digits)',
      'length(v_category_digits)<>(2+v_main_digits+v_sub_digits+v_secondary_digits)'
    );
    EXECUTE v_def;
  ELSIF position(
    'length(v_category_digits)<>(2+v_main_digits+v_sub_digits+v_secondary_digits)'
    IN v_def
  ) = 0 THEN
    RAISE EXCEPTION 'Unexpected item-code generator definition; aborting policy alignment';
  END IF;
END
$$;

UPDATE public.erp_program_policies
SET policy_value = jsonb_set(policy_value::jsonb, '{category_digits}', '8'::jsonb, true)::text,
    updated_at = now()
WHERE policy_key = 'item_code'
  AND left(policy_value, 1) = '{';

UPDATE public.erp_program_policies
SET policy_value = jsonb_set(
      policy_value::jsonb,
      '{item_fields}',
      '[
        {"name":"كود النشاط","digits":2},
        {"name":"فئة رئيسية","digits":2},
        {"name":"فئة فرعية","digits":2},
        {"name":"فئة ثانوية","digits":2},
        {"name":"البراند/الماركة بدون حروف","digits":4},
        {"name":"تسلسل الصنف","digits":3}
      ]'::jsonb,
      true
    )::text,
    updated_at = now()
WHERE policy_key = 'code_generation_registry'
  AND left(policy_value, 1) = '{';

DO $$
BEGIN
  IF EXISTS (
    WITH expected AS (
      SELECT i.id, i.company_id,
        coalesce(nullif(ip.policy_value::jsonb->>'prefix',''),'Itm')
        || regexp_replace(c.category_code,'[^0-9]','','g')
        || right(regexp_replace(b.brand_code,'[^0-9]','','g'),
                 coalesce(nullif(ip.policy_value::jsonb->>'brand_digits','')::integer,4))
        || right(i.item_code,
                 coalesce(nullif(ip.policy_value::jsonb->>'serial_digits','')::integer,3)) AS new_code
      FROM public.erp_items i
      JOIN public.erp_item_categories c
        ON c.id=i.category_id AND c.company_id=i.company_id
      JOIN public.erp_brands b
        ON b.id=i.brand_id AND b.company_id=i.company_id
      JOIN public.erp_program_policies ip
        ON ip.company_id=i.company_id AND ip.policy_key='item_code'
      WHERE length(regexp_replace(c.category_code,'[^0-9]','','g'))=8
        AND b.brand_code ~ '^[A-Za-z]{3}[0-9]{4}$'
        AND i.item_code IS NOT NULL
    )
    SELECT 1 FROM expected
    GROUP BY company_id,new_code
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Generated item codes would collide; no item codes were changed';
  END IF;
END
$$;

WITH expected AS (
  SELECT i.id, i.company_id,
    coalesce(nullif(ip.policy_value::jsonb->>'prefix',''),'Itm')
    || regexp_replace(c.category_code,'[^0-9]','','g')
    || right(regexp_replace(b.brand_code,'[^0-9]','','g'),
             coalesce(nullif(ip.policy_value::jsonb->>'brand_digits','')::integer,4))
    || right(i.item_code,
             coalesce(nullif(ip.policy_value::jsonb->>'serial_digits','')::integer,3)) AS new_code
  FROM public.erp_items i
  JOIN public.erp_item_categories c
    ON c.id=i.category_id AND c.company_id=i.company_id
  JOIN public.erp_brands b
    ON b.id=i.brand_id AND b.company_id=i.company_id
  JOIN public.erp_program_policies ip
    ON ip.company_id=i.company_id AND ip.policy_key='item_code'
  WHERE length(regexp_replace(c.category_code,'[^0-9]','','g'))=8
    AND b.brand_code ~ '^[A-Za-z]{3}[0-9]{4}$'
    AND i.item_code IS NOT NULL
)
UPDATE public.erp_items i
SET item_code=e.new_code, updated_at=now()
FROM expected e
WHERE i.id=e.id AND i.company_id=e.company_id
  AND i.item_code IS DISTINCT FROM e.new_code;

COMMIT;
