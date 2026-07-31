CREATE OR REPLACE FUNCTION workflow.import_sub_modules()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$

DECLARE

    v_config                 jsonb;

    v_root_module            text;

    v_sub_module_name        text;

    v_parent_module_id       bigint;

BEGIN



    --------------------------------------------------------------------------

    -- Read every metadata document

    --------------------------------------------------------------------------



    FOR v_config IN

        SELECT actionable_config

        FROM public.actionables_execution_metadata

        WHERE actionable_config IS NOT NULL

    LOOP



        ----------------------------------------------------------------------

        -- Root Module (Request)

        ----------------------------------------------------------------------



        FOR v_root_module IN

            SELECT key

            FROM jsonb_each(v_config)

        LOOP



            ------------------------------------------------------------------

            -- Get Parent Module Id

            ------------------------------------------------------------------



            SELECT in_record_id

            INTO v_parent_module_id

            FROM workflow.workflow_module

            WHERE module_api_name =

                lower(regexp_replace(v_root_module,'\s+','_','g'));



            IF v_parent_module_id IS NULL THEN

                RAISE EXCEPTION

                    'Workflow module "%" not found. Execute workflow.import_modules() first.',

                    v_root_module;

            END IF;



            ------------------------------------------------------------------

            -- Import Sub Modules

            ------------------------------------------------------------------



            FOR v_sub_module_name IN



                SELECT key

                FROM jsonb_each(

                    v_config

                        -> v_root_module

                        -> 'Sub Request Type'

                )



            LOOP



                INSERT INTO workflow.sub_module

                (

                    in_record_name,

                    sub_module_name,

                    sub_module_api_name,

                    ref_workflow_module_in_record_id,

                    description,

                    display_order,

                    is_active

                )

                SELECT

                    v_sub_module_name,

                    v_sub_module_name,

                    lower(regexp_replace(v_sub_module_name,'\s+','_','g')),

                    v_parent_module_id,

                    v_sub_module_name || ' Sub Module',

                    1,

                    TRUE

                WHERE NOT EXISTS

                (

                    SELECT 1

                    FROM workflow.sub_module sm

                    WHERE sm.ref_workflow_module_in_record_id =

                          v_parent_module_id

                    AND sm.sub_module_api_name =

                        lower(regexp_replace(v_sub_module_name,'\s+','_','g'))

                );



            END LOOP;



        END LOOP;



    END LOOP;



END;

$function$