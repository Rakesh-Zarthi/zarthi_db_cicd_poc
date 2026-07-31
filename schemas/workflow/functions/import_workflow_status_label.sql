CREATE OR REPLACE FUNCTION workflow.import_workflow_status_label()
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



    v_label_name        text;



    v_status_id         bigint;

    v_label_id          bigint;



    v_display_order     integer;



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

        -- Request / User

        ----------------------------------------------------------------------



        FOR v_root_module IN



            SELECT key

            FROM jsonb_each(v_config)



        LOOP



            ------------------------------------------------------------------

            -- Skip if no Sub Request Type

            ------------------------------------------------------------------



            IF NOT (v_config -> v_root_module ? 'Sub Request Type') THEN

                CONTINUE;

            END IF;



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



                IF NOT (v_sub_module ? 'Sub Request Status') THEN

                    CONTINUE;

                END IF;



                ----------------------------------------------------------------

                -- Statuses

                ----------------------------------------------------------------



                FOR v_status_name, v_status IN



                    SELECT key, value

                    FROM jsonb_each

                    (

                        v_sub_module

                            -> 'Sub Request Status'

                    )



                LOOP



                    ----------------------------------------------------------------

                    -- Lookup Status

                    ----------------------------------------------------------------



                    SELECT in_record_id

                    INTO v_status_id

                    FROM workflow.status

                    WHERE status_api_name =

                        lower(regexp_replace(v_status_name,'[^a-zA-Z0-9]+','_','g'));



                    IF v_status_id IS NULL THEN

                        CONTINUE;

                    END IF;



                    ----------------------------------------------------------------

                    -- No Labels

                    ----------------------------------------------------------------



                    IF NOT (v_status ? 'Labels') THEN

                        CONTINUE;

                    END IF;



                    v_display_order := 1;



                    ----------------------------------------------------------------

                    -- Labels

                    ----------------------------------------------------------------



                    FOR v_label_name IN



                        SELECT jsonb_array_elements_text

                        (

                            v_status -> 'Labels'

                        )



                    LOOP



                        ------------------------------------------------------------

                        -- Lookup Label

                        ------------------------------------------------------------



                        SELECT in_record_id

                        INTO v_label_id

                        FROM workflow.workflow_label

                        WHERE label_api_name =

                            lower(regexp_replace(v_label_name,'[^a-zA-Z0-9]+','_','g'));



                        IF v_label_id IS NULL THEN

                            CONTINUE;

                        END IF;



                        ------------------------------------------------------------

                        -- Insert

                        ------------------------------------------------------------



                        INSERT INTO workflow.workflow_status_label

                        (

                            in_record_name,



                            ref_workflow_status_in_record_id,

                            ref_workflow_label_in_record_id,



                            display_order,

                            is_active

                        )

                        VALUES

                        (

                            v_status_name || ' - ' || v_label_name,



                            v_status_id,

                            v_label_id,



                            v_display_order,

                            TRUE

                        )

                        ON CONFLICT

                        (

                            ref_workflow_status_in_record_id,

                            ref_workflow_label_in_record_id

                        )

                        DO NOTHING;



                        v_display_order := v_display_order + 1;



                    END LOOP;



                END LOOP;



            END LOOP;



        END LOOP;



    END LOOP;



END;



$function$