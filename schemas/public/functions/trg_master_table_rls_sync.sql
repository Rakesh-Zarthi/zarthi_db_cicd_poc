CREATE OR REPLACE FUNCTION public.trg_master_table_rls_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

BEGIN



IF NEW.rls_enabled IS DISTINCT FROM OLD.rls_enabled THEN



    PERFORM public.master_table_manage_rls(

        NEW.schema::text,

        NEW.table_api_name::text,

        NEW.rls_enabled

    );



END IF;



RETURN NEW;



END;

$function$