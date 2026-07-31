CREATE OR REPLACE FUNCTION public.master_trigger_001_wrapper_automation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$

BEGIN



    ----------------------------------------------------------------

    -- Run only if name changed

    ----------------------------------------------------------------

    IF NEW.trigger_api_name IS NOT DISTINCT FROM OLD.trigger_api_name THEN

        RETURN NEW;

    END IF;



    ----------------------------------------------------------------

    -- Call core logic (FIXED NAME)

    ----------------------------------------------------------------

    PERFORM public.master_trigger_001_001_update_trigger_api_name(

        NEW.ref_master_table_in_record_id,

        OLD.trigger_api_name,

        NEW.trigger_api_name

    );



    ----------------------------------------------------------------

    -- Keep metadata consistent

    ----------------------------------------------------------------

    NEW.trigger_name := NEW.trigger_api_name;

    NEW.dupe_trigger_api_name := OLD.trigger_api_name;



    RETURN NEW;



END;

$function$