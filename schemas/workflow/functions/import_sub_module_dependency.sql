CREATE OR REPLACE FUNCTION workflow.import_sub_module_dependency()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$

DECLARE

    v_config            jsonb;



    v_parent_module     text;

    v_parent_json       jsonb;



    v_child_module      text;



    v_parent_id         bigint;

    v_child_id          bigint;



    v_display_order     integer;

BEGIN



    FOR v_config IN

        SELECT actionable_config

        FROM public.actionables_execution_metadata

    LOOP



        ----------------------------------------------------------------------

        -- Request -> Sub Request Type

        ----------------------------------------------------------------------



        FOR v_parent_module, v_parent_json IN

            SELECT key, value

            FROM jsonb_each(v_config -> 'Request' -> 'Sub Request Type')

        LOOP



            ------------------------------------------------------------------

            -- Parent Sub Module

            ------------------------------------------------------------------



            SELECT sm.in_record_id

            INTO v_parent_id

            FROM workflow.sub_module sm

            WHERE sm.sub_module_name = v_parent_module;



            IF v_parent_id IS NULL THEN

                CONTINUE;

            END IF;



            ------------------------------------------------------------------

            -- Child Solutions

            ------------------------------------------------------------------



            IF v_parent_json ? 'Child Solutions' THEN



                v_display_order := 1;



                FOR v_child_module IN

                    SELECT jsonb_array_elements_text(

                        v_parent_json -> 'Child Solutions'

                    )

                LOOP



                    SELECT sm.in_record_id

                    INTO v_child_id

                    FROM workflow.sub_module sm

                    WHERE sm.sub_module_name = v_child_module;



                    IF v_child_id IS NULL THEN

                        CONTINUE;

                    END IF;



                    INSERT INTO workflow.sub_module_dependency

                    (

                        ref_sub_module_in_record_id_parent,

                        ref_sub_module_in_record_id_child,

                        dependency_type,

                        display_order,

                        is_active,

                        description

                    )

                    VALUES

                    (

                        v_parent_id,

                        v_child_id,

                        'Child',

                        v_display_order,

                        TRUE,

                        NULL

                    )

                    ON CONFLICT

                    (

                        ref_sub_module_in_record_id_parent,

                        ref_sub_module_in_record_id_child

                    )

                    DO NOTHING;



                    v_display_order := v_display_order + 1;



                END LOOP;



            END IF;



        END LOOP;



    END LOOP;



END;

$function$