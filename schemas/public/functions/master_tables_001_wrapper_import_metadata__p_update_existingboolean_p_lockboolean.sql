CREATE OR REPLACE FUNCTION public.master_tables_001_wrapper_import_metadata(p_update_existing boolean DEFAULT true, p_lock boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$



DECLARE



    ------------------------------------------------------------------

    -- Execution context

    ------------------------------------------------------------------

    v_user text := current_user;

    v_started_at timestamptz := clock_timestamp();

    v_duration numeric;



    ------------------------------------------------------------------

    -- Loop records

    ------------------------------------------------------------------

    sch record;

    tbl record;



    ------------------------------------------------------------------

    -- Counters

    ------------------------------------------------------------------

    v_success int := 0;

    v_failed  int := 0;

    v_total   int := 0;



    ------------------------------------------------------------------

    -- Per-table metrics

    ------------------------------------------------------------------

    v_result   jsonb;

    v_inserted int;

    v_updated  int;

    v_created  boolean;



    ------------------------------------------------------------------

    -- Error diagnostics (declared once ΓåÆ SAFE)

    ------------------------------------------------------------------

    v_err_msg text;

    v_err_detail text;

    v_err_hint text;

    v_err_context text;



    ------------------------------------------------------------------

    -- JSON iteration helper

    ------------------------------------------------------------------

    v_fail jsonb;



    ------------------------------------------------------------------

    -- Result accumulators

    ------------------------------------------------------------------

    v_failed_tables  jsonb := '[]'::jsonb;

    v_success_tables jsonb := '[]'::jsonb;



BEGIN



    ------------------------------------------------------------------

    -- Suppress noisy NOTICE (production hygiene)

    ------------------------------------------------------------------

    PERFORM set_config('client_min_messages', 'warning', true);



    ------------------------------------------------------------------

    -- Permission check

    ------------------------------------------------------------------

    IF v_user NOT IN ('postgres','admin2','admin','superuser') THEN

        RAISE EXCEPTION

        'Permission denied for user "%". Only admin/superuser allowed.',

        v_user

        USING ERRCODE='42501';

    END IF;



    ------------------------------------------------------------------

    -- Header

    ------------------------------------------------------------------

    RAISE NOTICE 'ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ';

    RAISE NOTICE '[START] metadata import';

    RAISE NOTICE '[USER=%][STRICT=%][LOCK=%]', v_user, p_update_existing, p_lock;

    RAISE NOTICE '[START_TIME=%]', v_started_at;

    RAISE NOTICE 'ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ';



    ------------------------------------------------------------------

    -- Main loop

    ------------------------------------------------------------------

    FOR sch IN

        SELECT nspname

        FROM pg_namespace

        WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast')

          AND nspname NOT LIKE 'pg_%'

        ORDER BY nspname

    LOOP



        RAISE NOTICE '';

        RAISE NOTICE 'ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ SCHEMA: % ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ', sch.nspname;



        FOR tbl IN

            SELECT c.relname AS table_name

            FROM pg_class c

            JOIN pg_namespace n ON n.oid = c.relnamespace

            WHERE n.nspname = sch.nspname

              AND c.relkind IN ('r','p')

              AND c.relname NOT IN (

    'master_key',

    'requests_to_data',

    'users_cc',

    'test_dynamic_table',

    'employee_data',

    'employee',

    'temp_gifts_image_processing',

    'test2feb26',

    'test_06feb26',

    'test_table',

    'test_table1',

    'v_valid',

    'security_events',

    'module',

    'date_table',

    'data_logs_fields',

    'awsdms_ddl_audit',

    'master_table_access_control_apps',

    'master_node_access_control_apps',

    'master_views_table_access_control',

    'master_views_node_access_control',

    'master_views_node',

    'master_views_table'

)

            ORDER BY c.relname

        LOOP



            v_total := v_total + 1;



            BEGIN



                v_result :=

                    public.master_tables_001_import_metadata(

                        sch.nspname,

                        tbl.table_name,

                        p_update_existing,

                        p_lock

                    );



                v_success := v_success + 1;



                ------------------------------------------------------------------

                -- Extract metrics

                ------------------------------------------------------------------

                v_inserted := COALESCE((v_result->>'inserted_nodes_count')::int,0);

                v_updated  := COALESCE((v_result->>'updated_nodes_count')::int,0);

                v_created  := COALESCE((v_result->>'master_table_created')::boolean,false);



                ------------------------------------------------------------------

                -- Success accumulation

                ------------------------------------------------------------------

                v_success_tables :=

                    v_success_tables ||

                    jsonb_build_object(

                        'schema', sch.nspname,

                        'table', tbl.table_name,

                        'master_table_id', v_result->>'master_table_id',

                        'master_table_created', v_created,

                        'inserted_nodes', v_inserted,

                        'updated_nodes', v_updated

                    );



                ------------------------------------------------------------------

                -- Logging

                ------------------------------------------------------------------

                IF v_created OR v_inserted > 0 OR v_updated > 0 THEN

                    RAISE NOTICE

                        '[OK][%.%][created=%][inserted=%][updated=%]',

                        sch.nspname,

                        tbl.table_name,

                        v_created,

                        v_inserted,

                        v_updated;

                ELSE

                    RAISE NOTICE

                        '[OK][%.%][NO_CHANGE]',

                        sch.nspname,

                        tbl.table_name;

                END IF;



            ------------------------------------------------------------------

            -- SAFE EXCEPTION BLOCK

            ------------------------------------------------------------------

            EXCEPTION WHEN OTHERS THEN



                v_failed := v_failed + 1;



                GET STACKED DIAGNOSTICS

                    v_err_msg     = MESSAGE_TEXT,

                    v_err_detail  = PG_EXCEPTION_DETAIL,

                    v_err_hint    = PG_EXCEPTION_HINT,

                    v_err_context = PG_EXCEPTION_CONTEXT;



                v_failed_tables :=

                    v_failed_tables ||

                    jsonb_build_object(

                        'schema', sch.nspname,

                        'table', tbl.table_name,

                        'error', v_err_msg,

                        'detail', v_err_detail,

                        'hint', v_err_hint,

                        'context', v_err_context

                    );



                RAISE WARNING

                    '[FAILED][%.%][ERROR=%]',

                    sch.nspname,

                    tbl.table_name,

                    v_err_msg;



            END;



        END LOOP;



    END LOOP;



    ------------------------------------------------------------------

    -- Duration

    ------------------------------------------------------------------

    v_duration :=

        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_started_at), 2);



    ------------------------------------------------------------------

    -- Summary

    ------------------------------------------------------------------

    RAISE NOTICE '';

    RAISE NOTICE 'ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ';

    RAISE NOTICE '[COMPLETE] metadata import';

    RAISE NOTICE '[DURATION=% sec]', v_duration;



    RAISE NOTICE

        '[RESULT][SUCCESS=%][FAILED=%][TOTAL=%][SUCCESS_RATE=%]',

        v_success,

        v_failed,

        v_total,

        CASE 

            WHEN v_total = 0 THEN '0%'

            ELSE ROUND((v_success::numeric / v_total) * 100, 2) || '%'

        END;



    ------------------------------------------------------------------

    -- Failure breakdown (SAFE JSON ITERATION)

    ------------------------------------------------------------------

    IF v_failed > 0 THEN



        RAISE WARNING 'ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ FAILURES ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ';



        FOR v_fail IN

            SELECT value FROM jsonb_array_elements(v_failed_tables)

        LOOP

            RAISE WARNING

                '[FAILED][%.%][ERROR=%]',

                v_fail->>'schema',

                v_fail->>'table',

                v_fail->>'error';

        END LOOP;



    END IF;



    IF v_success > 0 THEN

        RAISE NOTICE '[INFO] % tables processed successfully', v_success;

    END IF;



    RAISE NOTICE 'ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ';



    ------------------------------------------------------------------

    -- Return JSON

    ------------------------------------------------------------------

    RETURN jsonb_build_object(

        'status','complete',

        'duration_seconds', v_duration,

        'success_count', v_success,

        'failed_count', v_failed,

        'total_count', v_total,

        'success_tables', v_success_tables,

        'failed_tables', v_failed_tables

    );



END;

$function$