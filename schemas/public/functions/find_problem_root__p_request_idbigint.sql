CREATE OR REPLACE FUNCTION public.find_problem_root(p_request_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_cursor bigint := p_request_id;

    v_parent bigint;

    v_module text;

    v_seen   bigint[] := ARRAY[p_request_id];

BEGIN

    LOOP

        ------------------------------------------------------------------

        -- Find parent (services OR staffing)

        ------------------------------------------------------------------

        SELECT immediate_parent

        INTO v_parent

        FROM public.requests_services

        WHERE ref_requests_record_id = v_cursor;



        IF NOT FOUND THEN

            SELECT immediate_parent

            INTO v_parent

            FROM public.requests_staffing

            WHERE ref_requests_record_id = v_cursor;

        END IF;



        IF v_parent IS NULL THEN

            RAISE EXCEPTION

                'Hierarchy broken: No parent found for %',

                v_cursor;

        END IF;



        ------------------------------------------------------------------

        -- Cycle protection

        ------------------------------------------------------------------

        IF v_parent = ANY(v_seen) THEN

            RAISE EXCEPTION

                'Cycle detected while resolving root for %',

                p_request_id;

        END IF;



        v_seen := v_seen || v_parent;



        ------------------------------------------------------------------

        -- Check if parent is Problem

        ------------------------------------------------------------------

        SELECT module

        INTO v_module

        FROM public.requests

        WHERE in_record_id = v_parent;



        IF v_module = 'Problem' THEN

            RETURN v_parent;

        END IF;



        v_cursor := v_parent;

    END LOOP;

END;

$function$