CREATE OR REPLACE FUNCTION public.app_sign_off_find_usage_combination(p_request_id record_id, p_professional_id record_id, p_task single_line_text, p_required_qty numeric, p_tolerance numeric DEFAULT 0.01, p_max_rows integer DEFAULT 12)
 RETURNS TABLE(usage_id bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$

DECLARE

    combo BIGINT[];

BEGIN

    IF p_required_qty IS NULL OR p_required_qty < 0 THEN

        RAISE EXCEPTION 'Invalid required quantity %', p_required_qty;

    END IF;



    combo := public.search_usage_combo(

               p_request_id,

               p_professional_id,

               p_task,

               p_required_qty,

               1,

               ARRAY[]::BIGINT[],

               0,

               p_tolerance,

               p_max_rows

             );



    IF combo IS NOT NULL THEN

        RETURN QUERY SELECT unnest(combo) AS usage_id;

    ELSE

        RAISE NOTICE

            'No usage combination (within tolerance % ) found for request % (qty = %)',

            p_tolerance, p_request_id, p_required_qty;

        RETURN;

    END IF;

END;

$function$