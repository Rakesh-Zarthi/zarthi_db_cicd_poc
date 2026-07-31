CREATE OR REPLACE FUNCTION public.users_001_rebuild_insert_permissions()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$

DECLARE

    v_table_id bigint;

BEGIN

    FOR v_table_id IN

        SELECT DISTINCT mtacu.ref_master_table_in_record_id_to

        FROM public.master_table_access_control_users mtacu

        WHERE mtacu.permission @> ARRAY['Insert'::dropdown]

    LOOP

        PERFORM public.ac_rebuild_users_insert_permissions_for_table(v_table_id);

    END LOOP;



    RETURN NULL;

END;

$function$