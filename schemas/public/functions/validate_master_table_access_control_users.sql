CREATE OR REPLACE FUNCTION public.validate_master_table_access_control_users()
 RETURNS TABLE(acl_record_id bigint, node_id bigint, table_to_id bigint, is_root boolean, validation_error text)
 LANGUAGE plpgsql
AS $function$

BEGIN



    ----------------------------------------------------------------

    -- Rule 1

    ----------------------------------------------------------------

    RETURN QUERY

    SELECT

        a.in_record_id,

        a.ref_master_node_in_record_id_from::bigint,

        a.ref_master_table_in_record_id_to::bigint,

        a.is_root,

        'is_root can only be TRUE when ref_master_table_in_record_id_to = 34'

    FROM master_table_access_control_users a

    WHERE a.is_root = TRUE

      AND a.ref_master_table_in_record_id_to <> 34;



    ----------------------------------------------------------------

    -- Rule 2

    ----------------------------------------------------------------

    RETURN QUERY

    SELECT

        a.in_record_id,

        a.ref_master_node_in_record_id_from::bigint,

        a.ref_master_table_in_record_id_to::bigint,

        a.is_root,

        'ref_master_node_in_record_id_from is required when is_root = FALSE'

    FROM master_table_access_control_users a

    WHERE a.is_root = FALSE

      AND a.ref_master_node_in_record_id_from IS NULL;



    ----------------------------------------------------------------

    -- Rule 3

    ----------------------------------------------------------------

    RETURN QUERY

    SELECT

        a.in_record_id,

        a.ref_master_node_in_record_id_from::bigint,

        a.ref_master_table_in_record_id_to::bigint,

        a.is_root,

        format(

            'Node %s is not connected to table %s',

            a.ref_master_node_in_record_id_from,

            a.ref_master_table_in_record_id_to

        )

    FROM master_table_access_control_users a

    LEFT JOIN master_node mn

        ON mn.in_record_id = a.ref_master_node_in_record_id_from

    WHERE a.is_root = FALSE

      AND a.ref_master_node_in_record_id_from IS NOT NULL

      AND (

            mn.in_record_id IS NULL

         OR mn.ref_master_table_in_record_id_connected IS NULL

         OR mn.ref_master_table_in_record_id_connected <>

            a.ref_master_table_in_record_id_to

      );



END;

$function$