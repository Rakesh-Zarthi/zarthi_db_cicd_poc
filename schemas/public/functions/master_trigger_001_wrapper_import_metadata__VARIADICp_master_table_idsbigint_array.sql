CREATE OR REPLACE FUNCTION public.master_trigger_001_wrapper_import_metadata(VARIADIC p_master_table_ids bigint[] DEFAULT NULL::bigint[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    ----------------------------------------------------------------

    -- Security

    ----------------------------------------------------------------

    v_user text := current_user;



    ----------------------------------------------------------------

    -- Loop record

    ----------------------------------------------------------------

    rec_table record;



    ----------------------------------------------------------------

    -- Counters

    ----------------------------------------------------------------

    v_success int := 0;

    v_failed int := 0;

    v_total int := 0;



    ----------------------------------------------------------------

    -- Result accumulator

    ----------------------------------------------------------------

    v_results jsonb := '[]'::jsonb;

    v_result jsonb;



BEGIN



    ----------------------------------------------------------------

    -- Permission check

    ----------------------------------------------------------------

    IF v_user NOT IN ('postgres','admin2','admin','superuser') THEN

        RAISE EXCEPTION

        'Permission denied. Only admin/superuser may sync triggers.'

        USING ERRCODE = '42501';

    END IF;



    ----------------------------------------------------------------

    -- Normalize empty array to NULL

    ----------------------------------------------------------------

    p_master_table_ids :=

        NULLIF(p_master_table_ids, ARRAY[]::bigint[]);



    ----------------------------------------------------------------

    -- Loop tables

    ----------------------------------------------------------------

    FOR rec_table IN



        SELECT

            mt.in_record_id,

            mt."schema",

            mt.table_api_name

        FROM public.master_table mt

        WHERE

            COALESCE(cardinality(p_master_table_ids),0) = 0

            OR mt.in_record_id = ANY(p_master_table_ids)

        ORDER BY mt.in_record_id



    LOOP



        v_total := v_total + 1;



        BEGIN



            v_result :=

                public.master_trigger_001_import_metadata(

                    rec_table."schema",

                    rec_table.table_api_name,

                    true,   -- update_existing

                    true    -- lock

                );



            v_success := v_success + 1;



            v_results :=

                v_results ||

                jsonb_build_object(

                    'master_table_id', rec_table.in_record_id,

                    'schema', rec_table."schema",

                    'table', rec_table.table_api_name,

                    'result', v_result

                );



        EXCEPTION WHEN OTHERS THEN



            v_failed := v_failed + 1;



            v_results :=

                v_results ||

                jsonb_build_object(

                    'master_table_id', rec_table.in_record_id,

                    'schema', rec_table."schema",

                    'table', rec_table.table_api_name,

                    'error', SQLERRM

                );



        END;



    END LOOP;



    ----------------------------------------------------------------

    -- Return summary

    ----------------------------------------------------------------

    RETURN jsonb_build_object(



        'status', 'complete',



        'total', v_total,

        'success', v_success,

        'failed', v_failed,



        'results', v_results



    );



END;

$function$