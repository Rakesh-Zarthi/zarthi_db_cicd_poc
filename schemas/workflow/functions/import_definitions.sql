CREATE OR REPLACE FUNCTION workflow.import_definitions()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$

DECLARE

    v_config            jsonb;



    v_actionable_name   text;

    v_actionable        jsonb;



    v_category_name     text;

    v_type_name         text;



    v_category_id       bigint;

    v_type_id           bigint;



    v_bulk_creation     boolean;

    v_bulk_completion   boolean;



    v_display_order     integer := 1;



BEGIN



    FOR v_config IN

        SELECT actionable_config

        FROM public.actionables_execution_metadata

        WHERE actionable_config IS NOT NULL

    LOOP



        ----------------------------------------------------------------------

        -- Request -> Actionable

        ----------------------------------------------------------------------



        FOR v_actionable_name, v_actionable IN

            SELECT key, value

            FROM jsonb_each(

                v_config

                -> 'Request'

                -> 'Actionable'

            )

        LOOP



            ------------------------------------------------------------------

            -- Category

            ------------------------------------------------------------------



            v_category_name := trim(v_actionable ->> 'Category');



            SELECT c.in_record_id

            INTO v_category_id

            FROM workflow.category c

            WHERE c.category_api_name =

                lower(regexp_replace(v_category_name,'[^a-zA-Z0-9]+','_','g'));



            ------------------------------------------------------------------

            -- Workflow Type

            ------------------------------------------------------------------



            v_type_name := trim(v_actionable ->> 'Type');



            SELECT t.in_record_id

            INTO v_type_id

            FROM workflow.workflow_type t

            WHERE t.type_api_name =

                lower(regexp_replace(v_type_name,'[^a-zA-Z0-9]+','_','g'));



            ------------------------------------------------------------------

            -- Bulk Flags

            ------------------------------------------------------------------



            v_bulk_creation :=

                COALESCE(

                    (v_actionable ->> 'Can Be Created As Bulk')::boolean,

                    FALSE

                );



            v_bulk_completion :=

                COALESCE(

                    (v_actionable ->> 'Bulk Complete')::boolean,

                    FALSE

                );



            ------------------------------------------------------------------

            -- Insert Workflow Definition

            ------------------------------------------------------------------



            INSERT INTO workflow.definition

            (

                in_record_name,



                workflow_name,

                workflow_api_name,



                description,



                ref_workflow_category_in_record_id,

                ref_workflow_type_in_record_id,



                display_order,



                allow_bulk_creation,

                allow_bulk_completion,



                workflow_version,



                is_active

            )

            VALUES

            (

                v_actionable_name,



                v_actionable_name,

                lower(regexp_replace(v_actionable_name,'[^a-zA-Z0-9]+','_','g')),



                v_actionable_name || ' Workflow',



                v_category_id,

                v_type_id,



                v_display_order,



                v_bulk_creation,

                v_bulk_completion,



                1,



                TRUE

            )

            ON CONFLICT (workflow_api_name)

            DO NOTHING;



            v_display_order := v_display_order + 1;



        END LOOP;



    END LOOP;



END;

$function$