CREATE OR REPLACE FUNCTION public.etl_call_sync_requests_nodes()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN





IF pg_trigger_depth() > 1 THEN

    RETURN NEW;

END IF;



PERFORM public.etl_sync_new_added_requests_nodes();



RETURN NEW;





END;

$function$