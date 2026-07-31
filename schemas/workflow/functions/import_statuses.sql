CREATE OR REPLACE FUNCTION workflow.import_statuses()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$



DECLARE



    v_config                jsonb;



    v_root_module           text;



    v_sub_module_name       text;

    v_sub_module            jsonb;



    v_status_name           text;



    v_sub_module_id         bigint;



    v_display_order         integer;



BEGIN



    --------------------------------------------------------------------------

    -- Read all metadata documents

    --------------------------------------------------------------------------



    FOR v_config IN



        SELECT actionable_config

        FROM public.actionables_execution_metadata

        WHERE actionable_config IS NOT NULL



    LOOP



        ----------------------------------------------------------------------

        -- Root Modules

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



                SELECT sm.in_record_id

                INTO v_sub_module_id

                FROM workflow.sub_module sm

                JOIN workflow.workflow_module wm

                  ON wm.in_record_id = sm.ref_workflow_module_in_record_id

                WHERE wm.module_name = v_root_module

                  AND sm.sub_module_name = v_sub_module_name;



                IF v_sub_module_id IS NULL THEN



                    RAISE EXCEPTION

                    'Sub Module "%" not found. Execute workflow.import_sub_modules() first.',

                    v_sub_module_name;



                END IF;



                ------------------------------------------------------------------

                -- Statuses

                ------------------------------------------------------------------



                IF v_sub_module ? 'Sub Request Status' THEN



                    v_display_order := 1;



                    FOR v_status_name IN



                        SELECT key

                        FROM jsonb_each

                        (

                            v_sub_module -> 'Sub Request Status'

                        )



                    LOOP



                        INSERT INTO workflow.status

                        (

                            in_record_name,

                            ref_sub_module_in_record_id,

                            status_name,

                            status_api_name,

                            description,

                            display_order,

                            is_active

                        )

                        SELECT

                            v_status_name,

                            v_sub_module_id,

                            v_status_name,

                            lower(regexp_replace(v_status_name,'\s+','_','g')),

                            v_status_name || ' Status',

                            v_display_order,

                            TRUE

                        WHERE NOT EXISTS

                        (

                            SELECT 1

                            FROM workflow.status s

                            WHERE s.ref_sub_module_in_record_id = v_sub_module_id

                              AND s.status_api_name =

                                  lower(regexp_replace(v_status_name,'\s+','_','g'))

                        );



                        v_display_order := v_display_order + 1;



                    END LOOP;



                END IF;



            END LOOP;



        END LOOP;



    END LOOP;



END;

$function$