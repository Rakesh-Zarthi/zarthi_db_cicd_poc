CREATE OR REPLACE FUNCTION public.app_cds_get_table_schema_v001(p_table_api_name text, p_user_uuid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$

DECLARE

    v_table_id bigint;

    v_table_access_control_id bigint;

BEGIN

 

    -- Find the table

    SELECT mt.in_record_id

    INTO v_table_id

    FROM master_table mt

    WHERE mt.table_api_name = p_table_api_name

      AND mt.admin_restricted = false;

 

    IF NOT FOUND THEN

        RAISE EXCEPTION 'Table "%" not found', p_table_api_name;

    END IF;

 

    -- Find the user's table access control entry

    -- Replace this query if your lookup logic differs.

    SELECT tacu.in_record_id

    INTO v_table_access_control_id

    FROM master_table_access_control_users tacu

    WHERE tacu.ref_master_table_in_record_id_to = v_table_id

    LIMIT 1;

 

    RETURN (

        SELECT jsonb_build_object(

 

            'id', mt.in_record_id,

            'name', mt.table_name,

            'apiName', mt.table_api_name,

 

            'permissions',

            COALESCE(

                (

                    SELECT to_jsonb(permission)

                    FROM master_table_access_control_users tacu

                    WHERE tacu.in_record_id = v_table_access_control_id

                ),

                '[]'::jsonb

            ),

 

            'columns',

            COALESCE(

                (

                    SELECT jsonb_agg(

                        jsonb_build_object(

                            'apiName', mn.node_api_name,

                            'label', mn.node_label,

                            'dataType', mn.node_data_type,

                            'nullable', mn.is_nullable,

 

                            'permissions',

                            COALESCE(

                                (

                                    SELECT to_jsonb(permission)

                                    FROM master_node_access_control_users mnacu

                                    WHERE mnacu.ref_master_node_in_record_id_to = mn.in_record_id

                                      AND mnacu.ref_master_table_access_control_users_in_record_id =

                                          v_table_access_control_id

                                    LIMIT 1

                                ),

                                '[]'::jsonb

                            )

                        )

                        ORDER BY mn.node_sequence_number

                    )

                    FROM master_node mn

                    WHERE mn.ref_master_table_in_record_id = mt.in_record_id

                    AND mn.node_data_type NOT IN ( 'Many-One Lookup','Attachment')

                ),

                '[]'::jsonb

            )

 

        )

        FROM master_table mt

        WHERE mt.in_record_id = v_table_id

        AND mt."schema" <> 'workflow'

    );

 

END;

$function$