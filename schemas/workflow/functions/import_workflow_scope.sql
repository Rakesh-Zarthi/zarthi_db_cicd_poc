CREATE OR REPLACE FUNCTION workflow.import_workflow_scope()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$



DECLARE



    v_config            jsonb;



    v_root_module       text;



    v_actionable_name   text;

    v_actionable        jsonb;



    v_scope             jsonb;



    v_module_name       text;



    v_definition_id     bigint;

    v_module_id         bigint;

    v_sub_module_id     bigint;



    v_display_order     integer;



BEGIN



    --------------------------------------------------------------------------

    -- Every metadata record

    --------------------------------------------------------------------------



    FOR v_config IN



        SELECT actionable_config

        FROM public.actionables_execution_metadata

        WHERE actionable_config IS NOT NULL



    LOOP



        ----------------------------------------------------------------------

        -- Request / User

        ----------------------------------------------------------------------



        FOR v_root_module IN



            SELECT key

            FROM jsonb_each(v_config)



        LOOP



            IF NOT (

                v_config -> v_root_module ? 'Actionable'

            ) THEN

                CONTINUE;

            END IF;



            ------------------------------------------------------------------

            -- Workflow Module

            ------------------------------------------------------------------



            SELECT in_record_id

            INTO v_module_id

            FROM workflow.workflow_module

            WHERE module_api_name =

                lower(regexp_replace(v_root_module,'[^a-zA-Z0-9]+','_','g'));



            IF v_module_id IS NULL THEN

                CONTINUE;

            END IF;



            v_display_order := 1;



            ------------------------------------------------------------------

            -- Every Actionable

            ------------------------------------------------------------------



            FOR v_actionable_name, v_actionable IN



                SELECT key, value

                FROM jsonb_each

                (

                    v_config

                        -> v_root_module

                        -> 'Actionable'

                )



            LOOP



                --------------------------------------------------------------

                -- Workflow Definition

                --------------------------------------------------------------



                SELECT in_record_id

                INTO v_definition_id

                FROM workflow.definition

                WHERE workflow_api_name =

                    lower(regexp_replace(v_actionable_name,'[^a-zA-Z0-9]+','_','g'));



                IF v_definition_id IS NULL THEN

                    CONTINUE;

                END IF;



                --------------------------------------------------------------

                -- Allowed On

                --------------------------------------------------------------



                IF NOT (v_actionable ? 'Allowed On') THEN

                    CONTINUE;

                END IF;



                FOR v_scope IN



                    SELECT value

                    FROM jsonb_array_elements

                    (

                        v_actionable -> 'Allowed On'

                    ) AS t(value)



                LOOP



                    ----------------------------------------------------------

                    -- Module (Problem / Services / Roles ...)

                    ----------------------------------------------------------



                    v_module_name :=

                        COALESCE

                        (

                            v_scope ->> 'Module',

                            v_scope ->> 'module'

                        );



                    IF v_module_name IS NULL THEN

                        CONTINUE;

                    END IF;



                    ----------------------------------------------------------

                    -- Lookup Sub Module

                    ----------------------------------------------------------



                    SELECT in_record_id

                    INTO v_sub_module_id

                    FROM workflow.sub_module

                    WHERE sub_module_api_name =

                        lower(regexp_replace(v_module_name,'[^a-zA-Z0-9]+','_','g'));



                    IF v_sub_module_id IS NULL THEN

                        CONTINUE;

                    END IF;



                    ----------------------------------------------------------

                    -- Insert

                    ----------------------------------------------------------



                    INSERT INTO workflow.workflow_scope

                    (

                        in_record_name,



                        ref_workflow_definition_in_record_id,

                        ref_workflow_module_in_record_id,

                        ref_workflow_sub_module_in_record_id,



                        display_order,

                        is_active

                    )

                    VALUES

                    (

                        v_actionable_name || ' - ' || v_module_name,



                        v_definition_id,

                        v_module_id,

                        v_sub_module_id,



                        v_display_order,

                        TRUE

                    )

                    ON CONFLICT

                    (

                        ref_workflow_definition_in_record_id,

                        ref_workflow_module_in_record_id,

                        ref_workflow_sub_module_in_record_id

                    )

                    DO NOTHING;



                    v_display_order := v_display_order + 1;



                END LOOP;



            END LOOP;



        END LOOP;



    END LOOP;



END;



$function$