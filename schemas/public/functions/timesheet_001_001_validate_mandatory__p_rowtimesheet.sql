CREATE OR REPLACE FUNCTION public.timesheet_001_001_validate_mandatory(p_row timesheet)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

BEGIN

    IF p_row.ref_users_in_record_id_professional IS NULL THEN

        RAISE EXCEPTION 'Γ¥î Professional is mandatory.';

    END IF;



    IF p_row.ref_requests_in_record_id_request IS NULL THEN

        RAISE EXCEPTION 'Γ¥î Request is mandatory.';

    END IF;



    IF p_row.from_date_time IS NULL OR p_row.to_date_time IS NULL THEN

        RAISE EXCEPTION 'Γ¥î from_date_time and to_date_time are mandatory.';

    END IF;

END;

$function$