CREATE OR REPLACE FUNCTION public.check_view_duplicate_ids(p_schema text DEFAULT 'public'::text)
 RETURNS TABLE(view_name text, duplicate_id bigint, duplicate_count bigint)
 LANGUAGE plpgsql
AS $function$

DECLARE

    r record;

    v_sql text;

BEGIN

    FOR r IN

        SELECT table_name

        FROM information_schema.columns

        WHERE table_schema = p_schema

        AND column_name = 'id'

        AND table_name IN (

            SELECT table_name

            FROM information_schema.views

            WHERE table_schema = p_schema

        )

    LOOP

        BEGIN

            v_sql := format(

                'SELECT %L, id::bigint, COUNT(*)

                 FROM %I.%I

                 GROUP BY id

                 HAVING COUNT(*) > 1',

                r.table_name,

                p_schema,

                r.table_name

            );



            RETURN QUERY EXECUTE v_sql;



        EXCEPTION

            WHEN OTHERS THEN

                RAISE NOTICE 'Skipping view %.% due to error: %',

                    p_schema, r.table_name, SQLERRM;

        END;

    END LOOP;

END;

$function$