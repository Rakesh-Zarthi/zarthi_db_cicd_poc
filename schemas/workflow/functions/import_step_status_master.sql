CREATE OR REPLACE FUNCTION workflow.import_step_status_master()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$

DECLARE



    v_config            jsonb;



    v_root              text;



    v_actionable_name   text;

    v_actionable        jsonb;



    v_step_no           text;

    v_step              jsonb;



    v_step_status       text;



BEGIN



    --------------------------------------------------------------------------

    -- Metadata documents

    --------------------------------------------------------------------------



    FOR v_config IN

        SELECT actionable_config

        FROM public.actionables_execution_metadata

        WHERE actionable_config IS NOT NULL

    LOOP



        ----------------------------------------------------------------------

        -- Root Module (Request, User, ...)

        ----------------------------------------------------------------------



        FOR v_root IN

            SELECT key

            FROM jsonb_each(v_config)

        LOOP



            IF NOT (v_config -> v_root ? 'Actionable') THEN

                CONTINUE;

            END IF;



            ------------------------------------------------------------------

            -- Every Actionable

            ------------------------------------------------------------------



            FOR v_actionable_name, v_actionable IN

                SELECT key, value

                FROM jsonb_each(v_config -> v_root -> 'Actionable')

            LOOP



                IF NOT (v_actionable ? 'Steps') THEN

                    CONTINUE;

                END IF;



                ------------------------------------------------------------------

                -- Every Step

                ------------------------------------------------------------------



                FOR v_step_no, v_step IN

                    SELECT key, value

                    FROM jsonb_each(v_actionable -> 'Steps')

                LOOP



                    IF NOT (v_step ? 'Step Status') THEN

                        CONTINUE;

                    END IF;



                    ----------------------------------------------------------------

                    -- Step Statuses

                    ----------------------------------------------------------------



                    FOR v_step_status IN



                        SELECT jsonb_array_elements_text

                        (

                            v_step -> 'Step Status'

                        )



                    LOOP



                        INSERT INTO workflow.step_status_master

                        (

                            in_record_name,

                            step_status_name,

                            step_status_api_name,

                            description,

                            is_active

                        )

                        VALUES

                        (

                            v_step_status,

                            v_step_status,

                            lower(regexp_replace(v_step_status,'[^a-zA-Z0-9]+','_','g')),

                            v_step_status,

                            TRUE

                        )

                        ON CONFLICT (step_status_api_name)

                        DO NOTHING;



                    END LOOP;



                END LOOP;



            END LOOP;



        END LOOP;



    END LOOP;



END;

$function$