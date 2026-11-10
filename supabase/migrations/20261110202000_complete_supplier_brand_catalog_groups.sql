ALTER TABLE public.erp_brands
  ADD COLUMN IF NOT EXISTS brand_group text,
  ADD COLUMN IF NOT EXISTS display_order integer NOT NULL DEFAULT 1000;

-- Preserve the exact spelling from the supplier-brand list.
UPDATE public.erp_brands SET brand_name='ايديتا' WHERE brand_code='Bra012';
UPDATE public.erp_brands SET brand_name='ايطاليانو' WHERE brand_code='Bra017';
UPDATE public.erp_brands SET brand_name='الضحي' WHERE brand_code='Bra020';
UPDATE public.erp_brands SET brand_name='ارما' WHERE brand_code='Bra023';
UPDATE public.erp_brands SET brand_name='ايجيبت فودز' WHERE brand_code='Bra044';
UPDATE public.erp_brands SET brand_name='اريال' WHERE brand_code='Bra055';
UPDATE public.erp_brands SET brand_name='اولكر' WHERE brand_code='Bra062';

-- Preserve the two multi-brand groupings from the supplier identity list.
UPDATE public.erp_brands SET brand_group='بيبسي وسفن وميراندا'
WHERE brand_code IN ('Bra029','Bra030','Bra031');
UPDATE public.erp_brands SET brand_group='كوكاكولا وسبرايت وفانتا'
WHERE brand_code IN ('Bra032','Bra033','Bra034');

-- Add the final brand from the source list; the trigger assigns the next Bra code.
INSERT INTO public.erp_brands(company_id,brand_code,brand_name,brand_name_en,brand_group,is_active,is_system,display_order)
SELECT DISTINCT b.company_id,'','امتنان',NULL,NULL,true,false,68
FROM public.erp_brands b
WHERE b.is_system IS DISTINCT FROM true
  AND NOT EXISTS (
    SELECT 1 FROM public.erp_brands x
    WHERE x.company_id=b.company_id AND x.brand_name='امتنان'
  );

-- The first five brands are the user's explicitly requested additions;
-- the remaining rows follow the exact supplier-list order.
UPDATE public.erp_brands
SET display_order=CASE
  WHEN is_system=true THEN 0
  WHEN brand_code='Bra001' THEN 1
  WHEN brand_code='Bra002' THEN 2
  WHEN brand_code='Bra003' THEN 3
  WHEN brand_code='Bra004' THEN 4
  WHEN brand_code='Bra005' THEN 5
  WHEN brand_code='Bra007' THEN 6
  WHEN brand_code='Bra008' THEN 7
  WHEN brand_code='Bra009' THEN 8
  WHEN brand_code='Bra010' THEN 9
  WHEN brand_code='Bra011' THEN 10
  WHEN brand_code='Bra006' THEN 11
  WHEN brand_code='Bra012' THEN 12
  WHEN brand_code='Bra013' THEN 13
  WHEN brand_code='Bra014' THEN 14
  WHEN brand_code='Bra015' THEN 15
  WHEN brand_code='Bra016' THEN 16
  WHEN brand_code='Bra017' THEN 17
  WHEN brand_code='Bra018' THEN 18
  WHEN brand_code='Bra019' THEN 19
  WHEN brand_code='Bra020' THEN 20
  WHEN brand_code='Bra021' THEN 21
  WHEN brand_code='Bra022' THEN 22
  WHEN brand_code='Bra023' THEN 23
  WHEN brand_code='Bra024' THEN 24
  WHEN brand_code='Bra025' THEN 25
  WHEN brand_code='Bra026' THEN 26
  WHEN brand_code='Bra027' THEN 27
  WHEN brand_code='Bra028' THEN 28
  WHEN brand_code='Bra029' THEN 29
  WHEN brand_code='Bra030' THEN 30
  WHEN brand_code='Bra031' THEN 31
  WHEN brand_code='Bra032' THEN 32
  WHEN brand_code='Bra033' THEN 33
  WHEN brand_code='Bra034' THEN 34
  WHEN brand_code='Bra035' THEN 35
  WHEN brand_code='Bra036' THEN 36
  WHEN brand_code='Bra037' THEN 37
  WHEN brand_code='Bra038' THEN 38
  WHEN brand_code='Bra039' THEN 39
  WHEN brand_code='Bra040' THEN 40
  WHEN brand_code='Bra041' THEN 41
  WHEN brand_code='Bra042' THEN 42
  WHEN brand_code='Bra043' THEN 43
  WHEN brand_code='Bra044' THEN 44
  WHEN brand_code='Bra045' THEN 45
  WHEN brand_code='Bra046' THEN 46
  WHEN brand_code='Bra047' THEN 47
  WHEN brand_code='Bra048' THEN 48
  WHEN brand_code='Bra049' THEN 49
  WHEN brand_code='Bra050' THEN 50
  WHEN brand_code='Bra051' THEN 51
  WHEN brand_code='Bra052' THEN 52
  WHEN brand_code='Bra053' THEN 53
  WHEN brand_code='Bra054' THEN 54
  WHEN brand_code='Bra055' THEN 55
  WHEN brand_code='Bra056' THEN 56
  WHEN brand_code='Bra057' THEN 57
  WHEN brand_code='Bra058' THEN 58
  WHEN brand_code='Bra059' THEN 59
  WHEN brand_code='Bra060' THEN 60
  WHEN brand_code='Bra061' THEN 61
  WHEN brand_code='Bra062' THEN 62
  WHEN brand_code='Bra063' THEN 63
  WHEN brand_code='Bra064' THEN 64
  WHEN brand_code='Bra065' THEN 65
  WHEN brand_code='Bra066' THEN 66
  WHEN brand_code='Bra067' THEN 67
  WHEN brand_code='Bra068' THEN 68
  ELSE display_order
END;
