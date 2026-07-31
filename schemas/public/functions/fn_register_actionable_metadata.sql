CREATE OR REPLACE FUNCTION public.fn_register_actionable_metadata()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    IF (NEW.actionable_config -> 'module') IS NULL THEN

        RAISE EXCEPTION 'Invalid configuration: missing "module" key.';

    END IF;



    -- Auto register in master_key for reference

    PERFORM public.fn_register_master_key('Actionables_Metadata_' || NEW.in_record_id, NEW.in_ref_added_user);



    RETURN NEW;

END;

$function$