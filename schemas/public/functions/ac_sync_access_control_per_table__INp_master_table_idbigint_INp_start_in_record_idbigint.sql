CREATE OR REPLACE PROCEDURE public.ac_sync_access_control_per_table(IN p_master_table_id bigint, IN p_start_in_record_id bigint DEFAULT 0)
 LANGUAGE plpgsql
AS $procedure$

DECLARE

    v_table_api_name text;

    v_record         record;

    v_count          bigint := 0;

    v_sql            text;

BEGIN

    SELECT mt.table_api_name

    INTO v_table_api_name

    FROM public.master_table mt

    WHERE mt.in_record_id = p_master_table_id;



    IF v_table_api_name IS NULL THEN

        RAISE EXCEPTION

            'Master table % not found',

            p_master_table_id;

    END IF;



    RAISE NOTICE

        'ACL refresh started | table=% | start_record_id=%',

        v_table_api_name,

        p_start_in_record_id;



    v_sql := format(

        $f$

        SELECT

            t.in_ref_master_table,

            t.in_record_id

        FROM public.%I t

        WHERE t.in_record_id >= $1

        ORDER BY t.in_record_id

        $f$,

        v_table_api_name

    );



    FOR v_record IN

        EXECUTE v_sql

        USING p_start_in_record_id

    LOOP

        BEGIN

            PERFORM public.ac_self_child_update_master_access_wrapper(

                v_record.in_ref_master_table,

                v_record.in_record_id

            );



            v_count := v_count + 1;



            COMMIT;



            RAISE NOTICE

                'Processed row % | record_id=% | table=%',

                v_count,

                v_record.in_record_id,

                v_table_api_name;



        EXCEPTION

            WHEN OTHERS THEN

                RAISE NOTICE

                    'FAILED | record_id=% | table=% | error=%',

                    v_record.in_record_id,

                    v_table_api_name,

                    SQLERRM;



                COMMIT;

        END;

    END LOOP;



    RAISE NOTICE

        'ACL refresh completed | table=% | total processed=%',

        v_table_api_name,

        v_count;

END;

$procedure$