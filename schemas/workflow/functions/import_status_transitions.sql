CREATE OR REPLACE FUNCTION workflow.import_status_transitions()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$



DECLARE



    v_config            jsonb;



    v_root_module       text;



    v_sub_module_name   text;

    v_sub_module        jsonb;



    v_status_name       text;

    v_status            jsonb;



    v_next_status       text;



    v_sub_module_id     bigint;



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

            -- Sub Modules

            ------------------------------------------------------------------



            FOR v_sub_module_name, v_sub_module IN



                SELECT key, value

                FROM jsonb_each

                (

                    v_config

                        -> v_root_module

                        -> 'Sub Request Type'

                )



            LOOP



                ------------------------------------------------------------------

                -- Resolve Sub Module

                ------------------------------------------------------------------



                SELECT in_record_id

                INTO v_sub_module_id

                FROM workflow.sub_module

                WHERE sub_module_name = v_sub_module_name;



                IF v_sub_module_id IS NULL THEN

                    RAISE EXCEPTION

                    'Sub Module "%" not found. Execute import_sub_modules() first.',

                    v_sub_module_name;

                END IF;



                ------------------------------------------------------------------

                -- Statuses

                ------------------------------------------------------------------



                IF v_sub_module ? 'Sub Request Status' THEN



                    FOR v_status_name, v_status IN



                        SELECT key, value

                        FROM jsonb_each

                        (

                            v_sub_module -> 'Sub Request Status'

                        )



                    LOOP



                        ------------------------------------------------------------------

                        -- Next Status

                        ------------------------------------------------------------------



                        IF v_status ? 'Next Status' THEN



                            FOR v_next_status IN



                                SELECT jsonb_array_elements_text

                                (

                                    v_status -> 'Next Status'

                                )



                            LOOP



                                INSERT INTO workflow.status_transition

									(

									    ref_sub_module_in_record_id,

									    ref_from_status_in_record_id,

									    ref_to_status_in_record_id,

									    display_order,

									    is_active

									)

									SELECT

									    v_sub_module_id,

									    s_from.in_record_id,

									    s_to.in_record_id,

									    0,

									    TRUE

									FROM workflow.status s_from

									JOIN workflow.status s_to

									    ON s_to.ref_sub_module_in_record_id = s_from.ref_sub_module_in_record_id

									   AND s_to.status_name = v_next_status

									WHERE s_from.ref_sub_module_in_record_id = v_sub_module_id

									  AND s_from.status_name = v_status_name

									AND NOT EXISTS

									(

									    SELECT 1

									    FROM workflow.status_transition st

									    WHERE st.ref_sub_module_in_record_id = v_sub_module_id

									      AND st.ref_from_status_in_record_id = s_from.in_record_id

									      AND st.ref_to_status_in_record_id = s_to.in_record_id

									);



                            END LOOP;



                        END IF;



                    END LOOP;



                END IF;



            END LOOP;



        END LOOP;



    END LOOP;



END;



$function$