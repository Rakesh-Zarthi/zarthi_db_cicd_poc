CREATE OR REPLACE FUNCTION workflow.import_workflow_types()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$

DECLARE

    v_config jsonb;



    v_actionable_name text;

    v_actionable jsonb;



    v_type text;

BEGIN



    FOR v_config IN

        SELECT actionable_config

        FROM public.actionables_execution_metadata

        WHERE actionable_config IS NOT NULL

    LOOP



        FOR v_actionable_name, v_actionable IN

            SELECT key, value

            FROM jsonb_each(v_config -> 'Request' -> 'Actionable')

        LOOP



            v_type := trim(v_actionable ->> 'Type');



            IF v_type IS NULL OR v_type = '' THEN

                CONTINUE;

            END IF;



            INSERT INTO workflow.workflow_type

            (

                in_record_name,

                type_name,

                type_api_name,

                description,

                is_active

            )

            VALUES

            (

                v_type,

                v_type,

                lower(regexp_replace(v_type,'[^a-zA-Z0-9]+','_','g')),

                v_type || ' Workflow Type',

                TRUE

            )

            ON CONFLICT (type_api_name)

            DO NOTHING;



        END LOOP;



    END LOOP;



END;

$function$