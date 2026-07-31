CREATE OR REPLACE FUNCTION public.requests_autofill_root_parent()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

IF TG_TABLE_NAME IN (

'requests_services',

'requests_staffing'

) THEN



IF NEW.immediate_parent = NEW.ref_requests_record_id THEN

    RAISE EXCEPTION

        'Hierarchy violation: request % cannot be its own parent',

        NEW.ref_requests_record_id;

END IF;



ELSIF TG_TABLE_NAME = 'requests_sku_roles' THEN



IF NEW.immediate_parent = NEW.ref_requests_in_record_id THEN

    RAISE EXCEPTION

        'Hierarchy violation: request % cannot be its own parent',

        NEW.ref_requests_in_record_id;

END IF;



END IF;

    ------------------------------------------------------------------

    -- Skip if parent unchanged

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE'

       AND NEW.immediate_parent IS NOT DISTINCT FROM OLD.immediate_parent THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Delegate to shared utility

    ------------------------------------------------------------------

    NEW.root_parent :=

        public.requests_validations_parent(NEW.immediate_parent);



    RETURN NEW;

END;

$function$