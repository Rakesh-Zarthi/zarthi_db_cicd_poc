CREATE OR REPLACE PROCEDURE public.run_requests_acl_refresh()
 LANGUAGE plpgsql
AS $procedure$

DECLARE

    v_record record;

    v_count  bigint := 0;

BEGIN



    RAISE NOTICE 'ACL refresh started';



    FOR v_record IN

        SELECT

            r1.in_ref_master_table,

            r1.in_record_id

        FROM public.requests r1

        join users u1 on r1.owner = u1.in_record_id

        ORDER BY in_record_id

    LOOP



        PERFORM public.ac_self_child_update_master_access_wrapper(

            v_record.in_ref_master_table,

            v_record.in_record_id

        );



        v_count := v_count + 1;



        COMMIT;



        RAISE NOTICE

            'Processed row % | request_id=% | master_table=%',

            v_count,

            v_record.in_record_id,

            v_record.in_ref_master_table;



    END LOOP;



    RAISE NOTICE

        'ACL refresh completed | total processed=%',

        v_count;



END;

$procedure$