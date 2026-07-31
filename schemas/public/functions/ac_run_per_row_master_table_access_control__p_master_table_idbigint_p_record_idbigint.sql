CREATE OR REPLACE FUNCTION public.ac_run_per_row_master_table_access_control(p_master_table_id bigint, p_record_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$



BEGIN



    ------------------------------------------------------------

    -- VALIDATION

    ------------------------------------------------------------

    IF p_master_table_id IS NULL THEN

        RAISE EXCEPTION 'p_master_table_id cannot be null';

    END IF;



    IF p_record_id IS NULL THEN

        RAISE EXCEPTION 'p_record_id cannot be null';

    END IF;



    ------------------------------------------------------------

    -- VERIFY RECORD EXISTS

    ------------------------------------------------------------

    IF NOT EXISTS (

        SELECT 1

        FROM master_key mk

        WHERE mk.in_ref_master_table = p_master_table_id

          AND mk.in_record_id = p_record_id

    ) THEN

        RAISE EXCEPTION

            'Record % does not exist in master table %',

            p_record_id,

            p_master_table_id;

    END IF;



    ------------------------------------------------------------

    -- RUN ACL REBUILD

    ------------------------------------------------------------

    PERFORM public.ac_self_child_update_master_access_wrapper(

        p_master_table_id,

        p_record_id

    );



    RAISE NOTICE

        'ACL rebuild completed. Table ID: %, Record ID: %',

        p_master_table_id,

        p_record_id;



END;



$function$