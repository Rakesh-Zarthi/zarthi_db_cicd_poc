CREATE OR REPLACE FUNCTION public.requests_delete_requests_to_data_on_close()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

BEGIN

    -- Execute only when status changes to Close

    IF NEW.status = 'Close' AND OLD.status IS DISTINCT FROM 'Close' THEN



        DELETE FROM public.requests_to_data rtd

        WHERE rtd.ref_requests_in_record_id = NEW.in_record_id;



    END IF;



    RETURN NEW;

END;

$function$