CREATE OR REPLACE FUNCTION public.automation_regenerate_master_keys_for_dynamic_table(_table_api text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_api text := lower(trim(_table_api));

    v_schema text;

    v_tbl regclass;

    v_row record;

    v_key text;

    v_count int := 0;

BEGIN

    IF v_api IS NULL OR v_api = '' THEN

        RAISE EXCEPTION 'Missing table_api';

    END IF;



    SELECT COALESCE(mt.schema, 'public')

    INTO v_schema

    FROM public.master_table mt

    WHERE lower(mt.table_api_name) = v_api;



    IF v_schema IS NULL THEN

        RAISE NOTICE 'Table % not found in master_table', v_api;

        RETURN 0;

    END IF;



    v_tbl := format('%I.%I', v_schema, v_api)::regclass;



    PERFORM pg_advisory_xact_lock(hashtext(v_schema || '.' || v_api));



    FOR v_row IN EXECUTE format(

        'SELECT in_record_id FROM %I.%I',

        v_schema, v_api

    )

    LOOP

        BEGIN

            v_key :=

                public.automation_generate_master_key_for_dynamic_table(

                    v_api,

                    jsonb_build_object('master_id', v_row.in_record_id),

                    FALSE

                );

        EXCEPTION WHEN OTHERS THEN

            RAISE NOTICE

                'ΓÜá key gen failed: %.% id=% (%).',

                v_schema, v_api, v_row.in_record_id, SQLERRM;

            CONTINUE;

        END;



        IF v_key IS NOT NULL AND trim(v_key) <> '' THEN

            EXECUTE format(

                'UPDATE %I.%I SET in_record_name = $1 WHERE in_record_id = $2',

                v_schema, v_api

            )

            USING v_key, v_row.in_record_id;



            v_count := v_count + 1;

        END IF;

    END LOOP;



    RETURN v_count;

END;

$function$