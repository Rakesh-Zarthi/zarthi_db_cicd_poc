CREATE OR REPLACE FUNCTION public.ac_rebuild_users_insert_uuid_permissions_for_table(p_master_table_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$

DECLARE

    v_uuid_array jsonb;

    v_final jsonb;

BEGIN

    -- build UUID array from stored user IDs

    SELECT jsonb_agg(u.user_id ORDER BY u.in_record_id)

    INTO v_uuid_array

    FROM public.master_table mt

    CROSS JOIN LATERAL jsonb_array_elements_text(mt.insert_master_users_id_permissions) AS p(user_id)

    JOIN public.users u

        ON u.in_record_id = p.user_id::bigint

    WHERE mt.in_record_id = p_master_table_id;



    v_uuid_array := COALESCE(v_uuid_array, '[]'::jsonb);



    -- final structure

    v_final := jsonb_build_object('Insert', v_uuid_array);



    -- update only if changed

    UPDATE public.master_table mt

    SET insert_master_users_uuid_permissions = v_final

    WHERE mt.in_record_id = p_master_table_id

      AND mt.insert_master_users_uuid_permissions IS DISTINCT FROM v_final;



END;

$function$