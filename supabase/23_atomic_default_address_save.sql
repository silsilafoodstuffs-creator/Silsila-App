-- Atomically insert/update a user's default address.
-- Apply after 22_atomic_default_address.sql.
CREATE OR REPLACE FUNCTION public.save_default_address(
  p_address_id UUID,
  p_title TEXT,
  p_governorate TEXT,
  p_address TEXT,
  p_district TEXT DEFAULT NULL,
  p_village TEXT DEFAULT NULL,
  p_landmark TEXT DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS SETOF public.addresses
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_address public.addresses;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NULLIF(BTRIM(p_title), '') IS NULL
     OR NULLIF(BTRIM(p_governorate), '') IS NULL
     OR NULLIF(BTRIM(p_address), '') IS NULL THEN
    RAISE EXCEPTION 'Address title, governorate and details are required';
  END IF;

  IF (p_latitude IS NULL) <> (p_longitude IS NULL) THEN
    RAISE EXCEPTION 'Latitude and longitude must be provided together';
  END IF;

  IF p_latitude IS NOT NULL
     AND (p_latitude < -90 OR p_latitude > 90
          OR p_longitude < -180 OR p_longitude > 180) THEN
    RAISE EXCEPTION 'Coordinates are out of range';
  END IF;

  -- Serialize default-address changes for this user within the transaction.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::TEXT, 0));

  UPDATE public.addresses
  SET is_default = FALSE
  WHERE user_id = v_user_id AND is_default = TRUE;

  IF p_address_id IS NULL THEN
    INSERT INTO public.addresses (
      user_id, title, governorate, address, district, village,
      landmark, latitude, longitude, is_default
    ) VALUES (
      v_user_id, BTRIM(p_title), BTRIM(p_governorate), BTRIM(p_address),
      NULLIF(BTRIM(p_district), ''), NULLIF(BTRIM(p_village), ''),
      NULLIF(BTRIM(p_landmark), ''), p_latitude, p_longitude, TRUE
    )
    RETURNING * INTO v_address;
  ELSE
    UPDATE public.addresses
    SET title = BTRIM(p_title),
        governorate = BTRIM(p_governorate),
        address = BTRIM(p_address),
        district = NULLIF(BTRIM(p_district), ''),
        village = NULLIF(BTRIM(p_village), ''),
        landmark = NULLIF(BTRIM(p_landmark), ''),
        latitude = p_latitude,
        longitude = p_longitude,
        is_default = TRUE
    WHERE id = p_address_id AND user_id = v_user_id
    RETURNING * INTO v_address;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Address not found or not owned by current user';
    END IF;
  END IF;

  RETURN NEXT v_address;
END;
$$;

REVOKE ALL ON FUNCTION public.save_default_address(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_default_address(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION
) TO authenticated;
