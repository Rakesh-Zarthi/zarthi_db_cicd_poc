CREATE OR REPLACE FUNCTION public.requests_services_restrict_parent_update_for_specific_sku()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

BEGIN

    /*

        Restrict changing immediate_parent

        only for SKU 3112 and 3114

    */



    IF NEW.ref_services_sku IN (3112, 3114)

       AND NEW.immediate_parent IS DISTINCT FROM OLD.immediate_parent

    THEN

        RAISE EXCEPTION

        USING

            ERRCODE = 'check_violation',

            MESSAGE = format(

                'Cannot update parent for requests_services record_id %s when services_sku is %s',

                OLD.in_record_id,

                OLD.ref_services_sku

            );

    END IF;



    RETURN NEW;

END;

$function$