CREATE OR REPLACE FUNCTION public.ac_get_immediate_children(p_table_api_name text, p_record_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    v_table_id bigint;



    r record;



    v_sql text;



    v_partial_result jsonb;



    v_result jsonb := '[]'::jsonb;



BEGIN



    ------------------------------------------------------------

    -- RESOLVE TABLE ID

    ------------------------------------------------------------

    SELECT mt.in_record_id

    INTO v_table_id

    FROM public.master_table mt

    WHERE mt.table_api_name = p_table_api_name;



    IF v_table_id IS NULL THEN

        RAISE EXCEPTION

        'Invalid table_api_name: %',

        p_table_api_name;

    END IF;



    ------------------------------------------------------------

    -- SYSTEM CONTEXT

    ------------------------------------------------------------

    PERFORM set_config('row_security','off',true);



    ------------------------------------------------------------

    -- FIND IMMEDIATE CHILD RELATIONS

    ------------------------------------------------------------

    FOR r IN

    (

        SELECT *

        FROM

        (



            --------------------------------------------------

            -- ONE-MANY LOOKUP

            --------------------------------------------------

            SELECT

                table_from.in_record_id     AS table_from_id,

                table_from.table_api_name   AS table_from_api_name,

                n1.node_api_name            AS fk,

                table_to.in_record_id       AS table_to_id,

                table_to.table_api_name     AS table_to_api_name,

                'One-Many Lookup'           AS node_data_type

            FROM master_table_access_control_users m

            JOIN master_node n1

                ON n1.in_record_id = m.ref_master_node_in_record_id_from

            JOIN master_table table_from

                ON table_from.in_record_id = n1.ref_master_table_in_record_id

            JOIN master_table table_to

                ON table_to.in_record_id = m.ref_master_table_in_record_id_to

            WHERE n1.node_data_type = 'One-Many Lookup'

              AND table_from.in_record_id = v_table_id



            UNION



            --------------------------------------------------

            -- MANY-ONE LOOKUP

            --------------------------------------------------

            SELECT

                table_from.in_record_id     AS table_from_id,

                table_from.table_api_name   AS table_from_api_name,

                n2.node_api_name            AS fk,

                table_to.in_record_id       AS table_to_id,

                table_to.table_api_name     AS table_to_api_name,

                'Many-One Lookup'           AS node_data_type

            FROM master_table_access_control_users m

            JOIN master_node n1

                ON n1.in_record_id = m.ref_master_node_in_record_id_from

            JOIN master_node n2

                ON n1.ref_master_node_inverse_in_record_id = n2.in_record_id

            JOIN master_table table_from

                ON table_from.in_record_id = n1.ref_master_table_in_record_id

            JOIN master_table table_to

                ON table_to.in_record_id = m.ref_master_table_in_record_id_to

            WHERE n1.node_data_type = 'Many-One Lookup'

              AND table_from.in_record_id = v_table_id



        ) edges

    )

    LOOP



        ------------------------------------------------------------

        -- ONE-MANY LOOKUP

        ------------------------------------------------------------

        IF r.node_data_type = 'One-Many Lookup' THEN



            v_sql := format(

                '

                SELECT jsonb_agg(

                    jsonb_build_object(

                        ''child_table_api_name'', %L,

                        ''child_record_id'', c.in_record_id

                    )

                )

                FROM %I c

                WHERE c.%I = $1

                ',

                r.table_to_api_name,

                r.table_to_api_name,

                r.fk

            );



        ------------------------------------------------------------

        -- MANY-ONE LOOKUP

        ------------------------------------------------------------

        ELSIF r.node_data_type = 'Many-One Lookup' THEN



            v_sql := format(

                '

                SELECT jsonb_agg(

                    jsonb_build_object(

                        ''child_table_api_name'', %L,

                        ''child_record_id'', c.in_record_id

                    )

                )

                FROM %I c

                WHERE c.%I = $1

                ',

                r.table_to_api_name,

                r.table_to_api_name,

                r.fk

            );



        END IF;



        ------------------------------------------------------------

        -- EXECUTE QUERY

        ------------------------------------------------------------

        EXECUTE v_sql

        INTO v_partial_result

        USING p_record_id;



        ------------------------------------------------------------

        -- MERGE RESULTS

        ------------------------------------------------------------

        v_result :=

            v_result ||

            COALESCE(v_partial_result, '[]'::jsonb);



    END LOOP;



    ------------------------------------------------------------

    -- RETURN ARRAY

    ------------------------------------------------------------

    RETURN COALESCE(v_result, '[]'::jsonb);



END;

$function$