CREATE OR REPLACE FUNCTION public.validate_phone_number(p_phone text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$

BEGIN

    -- Validate format: +<country_code> <10-digit-number>

    IF p_phone ~ '^\+[0-9]{1,3}\s[0-9]{10}$' THEN

        RETURN TRUE;

    ELSE

        RAISE EXCEPTION 'Invalid phone number format. Expected format: +CCC XXXXXXXXXX (e.g., +91 1234567891)';

    END IF;

END;

$function$