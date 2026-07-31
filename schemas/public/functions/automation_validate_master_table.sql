CREATE OR REPLACE FUNCTION public.automation_validate_master_table()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    IF NEW.table_api_name IS DISTINCT FROM OLD.table_api_name THEN

        RAISE EXCEPTION '≡ƒÜ½ Changing table_api_name is not allowed.';

    END IF;

    RETURN NEW;

END;

$function$