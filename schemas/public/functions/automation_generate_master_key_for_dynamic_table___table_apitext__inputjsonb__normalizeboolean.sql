CREATE OR REPLACE FUNCTION public.automation_generate_master_key_for_dynamic_table(_table_api text, _input jsonb, _normalize boolean DEFAULT true)
 RETURNS text
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_api text := lower(trim(_table_api));  -- normalized table API

    v_master_id bigint := NULL;

    v_is_json boolean := TRUE;



    v_rec record;

    v_colval text;

    v_piece text;

    v_parts text[] := ARRAY[]::text[];

    v_final text;

BEGIN

    ----------------------------------------------------------------------

    -- 1. Detect SQL-mode or JSON-mode

    ----------------------------------------------------------------------

    IF _input ? 'master_id' THEN

        BEGIN

            v_master_id := (_input ->> 'master_id')::bigint;

            v_is_json := FALSE;

        EXCEPTION WHEN OTHERS THEN

            v_master_id := NULL;

        END;

    END IF;





    ----------------------------------------------------------------------

    -- 2. Fetch master-key nodes (CORRECT JOIN)

    ----------------------------------------------------------------------

    FOR v_rec IN

        SELECT 

            mn.node_api_name,

            COALESCE(mn.pre_text_master_key, '') AS pre_text,

            COALESCE(mn.post_text_master_key, '') AS post_text,

            COALESCE(mn.master_key_sequence, 0) AS seq

        FROM public.master_node mn

        JOIN public.master_table mt 

            ON mt.in_record_id = mn.ref_master_table_in_record_id

        WHERE lower(mt.table_api_name) = v_api

          AND COALESCE(mn.is_master_key, FALSE) = TRUE

        ORDER BY seq

    LOOP



        ----------------------------------------------------------------------

        -- 3. Extract column value

        ----------------------------------------------------------------------

        v_colval := NULL;



        IF v_is_json THEN

            --------------------------

            -- JSON MODE

            --------------------------

            IF _input ? v_rec.node_api_name THEN

                v_colval := trim(_input ->> v_rec.node_api_name);

            END IF;



        ELSE

            --------------------------

            -- SQL MODE

            --------------------------

            BEGIN

                EXECUTE format(

                    'SELECT %I::text FROM public.%I WHERE in_record_id = $1',

                    v_rec.node_api_name,

                    v_api

                )

                INTO v_colval

                USING v_master_id;



            EXCEPTION WHEN OTHERS THEN

                v_colval := NULL;

            END;

        END IF;





        ----------------------------------------------------------------------

        -- 4. Skip if no data (NO FALLBACK TO node_label)

        ----------------------------------------------------------------------

        IF v_colval IS NULL OR trim(v_colval) = '' THEN

            CONTINUE;

        END IF;





        ----------------------------------------------------------------------

        -- 5. Build key segment

        ----------------------------------------------------------------------

        IF v_rec.pre_text <> '' AND v_rec.post_text = '' THEN

            v_piece := v_rec.pre_text || ' ' || v_colval;



        ELSIF v_rec.pre_text = '' AND v_rec.post_text <> '' THEN

            v_piece := v_colval || ' ' || v_rec.post_text;



        ELSIF v_rec.pre_text <> '' AND v_rec.post_text <> '' THEN

            v_piece := v_rec.pre_text || ' ' || v_colval || ' ' || v_rec.post_text;



        ELSE

            v_piece := v_colval;

        END IF;



        v_parts := v_parts || trim(v_piece);

    END LOOP;





    ----------------------------------------------------------------------

    -- 6. Assemble final key

    ----------------------------------------------------------------------

    IF array_length(v_parts, 1) IS NULL THEN

        RETURN NULL;

    END IF;



    v_final := array_to_string(v_parts, ' ');

    v_final := regexp_replace(v_final, '\s+', ' ', 'g');

    v_final := trim(v_final);



    RETURN v_final;

END;

$function$