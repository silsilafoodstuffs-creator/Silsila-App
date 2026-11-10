BEGIN;

DO $preflight$
DECLARE
  v_egypt_count integer;
  v_conflict_count integer;
BEGIN
  SELECT count(*) INTO v_egypt_count
  FROM public.erp_countries
  WHERE name_ar='مصر' AND is_active=true;

  IF v_egypt_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one active Egypt country row; found %', v_egypt_count;
  END IF;

  SELECT count(*) INTO v_conflict_count
  FROM public.erp_countries
  WHERE country_code='20'
    AND name_ar <> 'مصر';

  IF v_conflict_count > 0 THEN
    RAISE EXCEPTION 'Country code 20 is already assigned to another country';
  END IF;
END;
$preflight$;

-- Geographic records already use 20 as their inherited country segment
-- (e.g. Rig20010201). Align the country master used by future geo/customer
-- generators without rewriting any issued geographic or customer identifiers.
UPDATE public.erp_countries
SET country_code='20', updated_at=now()
WHERE name_ar='مصر'
  AND is_active=true
  AND country_code='02';

DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.erp_countries
    WHERE name_ar='مصر' AND country_code='20' AND is_active=true
  ) THEN
    RAISE EXCEPTION 'Egypt country code did not resolve to 20';
  END IF;
END;
$verify$;

COMMIT;
