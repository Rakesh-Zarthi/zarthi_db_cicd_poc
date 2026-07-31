CREATE OR REPLACE FUNCTION public.fn_regenerate_strict_triggers()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$

DECLARE

    caller text := current_user;

    missing jsonb := '[]'::jsonb;

    fixed jsonb := '[]'::jsonb;

    mt record;

    expected_map jsonb := COALESCE(public.fn_expected_triggers(), '{}'::jsonb);

    present_triggers text[];

    expected_trigger text;

BEGIN

    IF caller NOT IN ('postgres','admin','superuser') THEN

        RAISE EXCEPTION 'Permission denied. Only admin/superuser may regenerate triggers. Current user=%', caller;

    END IF;



    FOR mt IN

        SELECT in_record_id, table_api_name

        FROM public.master_table

        ORDER BY table_api_name

    LOOP

        -- gather present triggers for table

        SELECT array_agg(trigger_name::text) FILTER (WHERE trigger_name IS NOT NULL)

        INTO present_triggers

        FROM information_schema.triggers

        WHERE trigger_schema = 'public'

          AND event_object_table = mt.table_api_name;



        IF present_triggers IS NULL THEN

            present_triggers := ARRAY[]::text[];

        END IF;



        -- check master_table expected triggers

        IF expected_map ? 'master_table' THEN

            FOR expected_trigger IN

                SELECT jsonb_array_elements_text(expected_map -> 'master_table')

            LOOP

                IF NOT expected_trigger = ANY(present_triggers) THEN

                    missing := missing || jsonb_build_object('table', mt.table_api_name, 'trigger', expected_trigger);

                    -- attempt to attach only the missing trigger(s)

                    BEGIN

                        PERFORM public.automation_attach_global_triggers(mt.table_api_name);

                        fixed := fixed || jsonb_build_object('table', mt.table_api_name, 'trigger', expected_trigger);

                    EXCEPTION WHEN OTHERS THEN

                        missing := missing || jsonb_build_object('table', mt.table_api_name, 'trigger', expected_trigger, 'error', SQLERRM);

                    END;

                END IF;

            END LOOP;

        END IF;



        -- check master_node expected triggers

        IF expected_map ? 'master_node' THEN

            FOR expected_trigger IN

                SELECT jsonb_array_elements_text(expected_map -> 'master_node')

            LOOP

                IF NOT expected_trigger = ANY(present_triggers) THEN

                    missing := missing || jsonb_build_object('table', mt.table_api_name, 'trigger', expected_trigger);

                    BEGIN

                        PERFORM public.automation_attach_global_triggers(mt.table_api_name);

                        fixed := fixed || jsonb_build_object('table', mt.table_api_name, 'trigger', expected_trigger);

                    EXCEPTION WHEN OTHERS THEN

                        missing := missing || jsonb_build_object('table', mt.table_api_name, 'trigger', expected_trigger, 'error', SQLERRM);

                    END;

                END IF;

            END LOOP;

        END IF;

    END LOOP;



    RETURN jsonb_build_object('missing_triggers_detected', COALESCE(missing, '[]'::jsonb), 'triggers_fixed', COALESCE(fixed, '[]'::jsonb));

END;

$function$