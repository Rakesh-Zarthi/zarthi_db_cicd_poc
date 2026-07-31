CREATE OR REPLACE PROCEDURE public.ac_refresh_master_table_access_permissions(IN p_table_ids integer[] DEFAULT NULL::integer[])
 LANGUAGE plpgsql
AS $procedure$

DECLARE

    v_table_id       int;

    v_table_api_name text;

    v_in_record_id   bigint;

    v_record_count   bigint;

    v_total_count    bigint := 0;

BEGIN



    RAISE NOTICE 'ACL refresh started';



    /*

      Case 1: p_table_ids provided -> process only those tables

      Case 2: NULL -> process all tables

    */



    FOR v_table_id, v_table_api_name IN

        SELECT

            mt.in_record_id,

            mt.table_api_name

        FROM public.master_table mt

        WHERE

              (p_table_ids IS NOT NULL AND mt.in_record_id = ANY (p_table_ids))

           OR (p_table_ids IS NULL)

        ORDER BY mt.in_record_id

    LOOP



        RAISE NOTICE

            'Processing Table: % (ID: %)',

            v_table_api_name,

            v_table_id;



        v_record_count := 0;



        FOR v_in_record_id IN

            SELECT mk.in_record_id

            FROM public.master_key mk

            WHERE mk.in_ref_master_table = v_table_id

            ORDER BY mk.in_record_id

        LOOP



            PERFORM public.ac_self_child_update_master_access_wrapper(

                v_table_id,

                v_in_record_id

            );



            v_record_count := v_record_count + 1;

            v_total_count  := v_total_count + 1;



            COMMIT;



            RAISE NOTICE

                '---------------------------------------------------------Processed % | Table=% | Record ID=%',

                v_total_count,

                v_table_api_name,

                v_in_record_id;



        END LOOP;



        RAISE NOTICE

            'Completed Table: % | Records Processed=%',

            v_table_api_name,

            v_record_count;



    END LOOP;



    RAISE NOTICE

        'ACL refresh completed | Total Records Processed=%',

        v_total_count;



END;

$procedure$