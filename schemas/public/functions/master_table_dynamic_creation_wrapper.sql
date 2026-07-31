CREATE OR REPLACE FUNCTION public.master_table_dynamic_creation_wrapper()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    ------------------------------------------------------------------

    -- Ensure table is created first (depends on trigger order!)

    ------------------------------------------------------------------



    -- Attach global triggers to newly created dynamic table

    PERFORM automation_attach_global_triggers(NEW.table_api_name);



    RETURN NEW;

END;

$function$