CREATE OR REPLACE FUNCTION public.ac_run_complete_master_table_access_control(p_table_ids integer[] DEFAULT NULL::integer[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$



DECLARE

    v_table_id        int;

    v_table_api_name  text;

    v_in_record_id    bigint;

    v_record_count    int;

    v_error_msg       text;



BEGIN



    /*

      Case 1: p_table_ids provided ΓåÆ run only those tables

      Case 2: NULL ΓåÆ run for all tables

    */



    FOR v_table_id, v_table_api_name IN

        SELECT mt.in_record_id, mt.table_api_name

        FROM master_table mt

        WHERE

              (p_table_ids IS NOT NULL AND mt.in_record_id = ANY(p_table_ids))

           OR (p_table_ids IS NULL)

        ORDER BY mt.in_record_id

    LOOP



        RAISE NOTICE 'Processing Table: % (ID: %)',

            v_table_api_name,

            v_table_id;



        v_record_count := 0;



        ------------------------------------------------------------

        -- LOOP RECORDS

        ------------------------------------------------------------

        FOR v_in_record_id IN

            SELECT mk.in_record_id

            FROM master_key mk

            WHERE mk.in_ref_master_table = v_table_id

            ORDER BY mk.in_record_id

        LOOP

            BEGIN



                v_record_count := v_record_count + 1;



                RAISE NOTICE

                    '  -> Processing Table: %, Record ID: %',

                    v_table_api_name,

                    v_in_record_id;



                PERFORM public.ac_self_child_update_master_access_wrapper(

                    v_table_id,

                    v_in_record_id

                );



            EXCEPTION WHEN OTHERS THEN



                v_error_msg := SQLERRM;



                RAISE WARNING

                    '  !! FAILED Table: %, Record ID: %, Error: %',

                    v_table_api_name,

                    v_in_record_id,

                    v_error_msg;



            END;

        END LOOP;



        RAISE NOTICE

            'Completed Table: %, Total Records Attempted: %',

            v_table_api_name,

            v_record_count;



    END LOOP;



    RAISE NOTICE 'All tables processed successfully.';



END;



$function$