CREATE OR REPLACE FUNCTION public.ac_run_per_record_complete_master_table_access_control(p_table_id bigint, p_record_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$



DECLARE

    v_table_api_name text;

    v_error_msg      text;



BEGIN



    SELECT mt.table_api_name

    INTO v_table_api_name

    FROM master_table mt

    WHERE mt.in_record_id = p_table_id;



    IF v_table_api_name IS NULL THEN

        RAISE EXCEPTION 'Table ID % not found in master_table', p_table_id;

    END IF;



    RAISE NOTICE

        'Processing Table: %, Record ID: %',

        v_table_api_name,

        p_record_id;



    BEGIN



        PERFORM public.ac_self_child_update_master_access_wrapper(

            p_table_id,

            p_record_id

        );



        RAISE NOTICE

            'Completed Table: %, Record ID: %',

            v_table_api_name,

            p_record_id;



    EXCEPTION WHEN OTHERS THEN



        v_error_msg := SQLERRM;



        RAISE EXCEPTION

            'FAILED Table: %, Record ID: %, Error: %',

            v_table_api_name,

            p_record_id,

            v_error_msg;



    END;



END;



$function$