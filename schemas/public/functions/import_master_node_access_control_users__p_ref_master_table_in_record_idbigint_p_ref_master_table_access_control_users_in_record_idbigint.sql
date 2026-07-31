CREATE OR REPLACE FUNCTION public.import_master_node_access_control_users(p_ref_master_table_in_record_id bigint, p_ref_master_table_access_control_users_in_record_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_rows_inserted bigint;

BEGIN



    INSERT INTO public.master_node_access_control_users (

        ref_master_table_access_control_users_in_record_id,

        ref_master_node_in_record_id_to,

        permission

    )

    SELECT

    p_ref_master_table_access_control_users_in_record_id,

    mn.in_record_id,

    ARRAY['Read']::public."_dropdown"

FROM public.master_node mn

WHERE mn.ref_master_table_in_record_id = p_ref_master_table_in_record_id

  AND mn.node_api_name NOT IN (

        'in_ref_master_table',

        'in_ref_master_user_uuid',

        'zoho_id',

        'in_ref_added_user_uuid',

        'in_ref_modified_user_uuid',

        'in_ref_master_users_role_id',

        'in_ref_master_request_id',

        'in_ref_master_users_id',

        'in_modified_time',

        'in_added_time'

  )

  AND NOT EXISTS (

        SELECT 1

        FROM public.master_node_access_control_users mnacu

        WHERE mnacu.ref_master_table_access_control_users_in_record_id =

              p_ref_master_table_access_control_users_in_record_id

          AND mnacu.ref_master_node_in_record_id_to = mn.in_record_id

  );



    GET DIAGNOSTICS v_rows_inserted = ROW_COUNT;



    RETURN v_rows_inserted;

END;

$function$