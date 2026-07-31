CREATE OR REPLACE FUNCTION public.tg_detect_requests_cycle()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    PERFORM public.fn_detect_requests_cycle(

        NEW.ref_requests_record_id,

        NEW.immediate_parent

    );

    RETURN NULL;

END;

$function$