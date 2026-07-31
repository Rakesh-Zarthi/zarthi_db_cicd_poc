CREATE OR REPLACE FUNCTION public.ac_rebuild_users_insert_permissions_for_table(p_master_table_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_permissions jsonb;

BEGIN

    SELECT jsonb_agg(u_id ORDER BY u_id::bigint)

    INTO v_permissions

    FROM (

        SELECT DISTINCT u.in_record_id::text AS u_id

        FROM public.users u

        JOIN public.master_table_access_control_users mtacu

            ON TRUE

        WHERE mtacu.ref_master_table_in_record_id_to = p_master_table_id

          AND mtacu.permission @> ARRAY['Insert'::dropdown]

    ) t;



    v_permissions := COALESCE(v_permissions, '[]'::jsonb);



    UPDATE public.master_table mt

    SET insert_master_users_id_permissions = v_permissions

    WHERE mt.in_record_id = p_master_table_id

      AND mt.insert_master_users_id_permissions IS DISTINCT FROM v_permissions;



END;

$function$