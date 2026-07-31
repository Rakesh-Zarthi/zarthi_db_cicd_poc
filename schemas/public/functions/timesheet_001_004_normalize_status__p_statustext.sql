CREATE OR REPLACE FUNCTION public.timesheet_001_004_normalize_status(p_status text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_status text;

BEGIN

    IF p_status IS NULL THEN

        RETURN NULL;

    END IF;



    v_status := initcap(lower(trim(p_status)));



    IF v_status NOT IN ('Open','Awaiting Approval','Approve') THEN

        RAISE EXCEPTION

            'Γ¥î Invalid status "%". Allowed Status: Open, Awaiting Approval, Approve',

            p_status;

    END IF;



    RETURN v_status;

END;

$function$