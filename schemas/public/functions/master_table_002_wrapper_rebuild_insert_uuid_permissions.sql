CREATE OR REPLACE FUNCTION public.master_table_002_wrapper_rebuild_insert_uuid_permissions()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$

BEGIN

    -- only act when value actually changes

    IF NEW.insert_master_users_id_permissions IS DISTINCT FROM OLD.insert_master_users_id_permissions THEN

        PERFORM public.ac_rebuild_users_insert_uuid_permissions_for_table(NEW.in_record_id);

    END IF;



    RETURN NEW;

END;

$function$