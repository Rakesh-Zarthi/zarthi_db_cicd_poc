CREATE OR REPLACE FUNCTION public.master_table_toggle_rls(p_enable boolean)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    r RECORD;

BEGIN

    FOR r IN

        SELECT 

            mt.schema AS schema_name,

            mt.table_api_name AS table_name

        FROM public.master_table mt

        WHERE mt.rls_enabled = true

    LOOP

        BEGIN

            IF p_enable THEN

                EXECUTE format(

                    'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY;',

                    r.schema_name,

                    r.table_name

                );

            ELSE

                EXECUTE format(

                    'ALTER TABLE %I.%I DISABLE ROW LEVEL SECURITY;',

                    r.schema_name,

                    r.table_name

                );

            END IF;



            RAISE NOTICE 'RLS % on %.%',

                CASE WHEN p_enable THEN 'ENABLED' ELSE 'DISABLED' END,

                r.schema_name,

                r.table_name;



        EXCEPTION

            WHEN undefined_table THEN

                RAISE WARNING 'Table not found: %.%', r.schema_name, r.table_name;



            WHEN insufficient_privilege THEN

                RAISE WARNING 'Permission denied: %.%', r.schema_name, r.table_name;



            WHEN others THEN

                RAISE WARNING 'Failed for %.%: %',

                    r.schema_name,

                    r.table_name,

                    SQLERRM;

        END;

    END LOOP;

END;

$function$