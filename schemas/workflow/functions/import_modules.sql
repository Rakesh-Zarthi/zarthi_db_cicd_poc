CREATE OR REPLACE FUNCTION workflow.import_modules()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$

DECLARE

    v_config         jsonb;

    v_module_name    text;

BEGIN



    FOR v_config IN

        SELECT actionable_config

        FROM public.actionables_execution_metadata

        WHERE actionable_config IS NOT NULL

    LOOP



        ----------------------------------------------------------------------

        -- Import Root Modules

        ----------------------------------------------------------------------



        FOR v_module_name IN

            SELECT key

            FROM jsonb_each(v_config)

        LOOP



            INSERT INTO workflow.workflow_module

            (

                in_record_name,

                module_name,

                module_api_name,

                description,

                display_order,

                is_active

            )

            SELECT

                v_module_name,

                v_module_name,

                lower(regexp_replace(v_module_name, '\s+', '_', 'g')),

                v_module_name || ' Module',

                1,

                TRUE

            WHERE NOT EXISTS

            (

                SELECT 1

                FROM workflow.workflow_module wm

                WHERE lower(wm.module_api_name) =

                      lower(regexp_replace(v_module_name, '\s+', '_', 'g'))

            );



        END LOOP;



    END LOOP;



END;

$function$