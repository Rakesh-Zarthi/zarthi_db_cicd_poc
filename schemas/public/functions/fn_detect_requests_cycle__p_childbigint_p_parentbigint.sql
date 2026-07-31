CREATE OR REPLACE FUNCTION public.fn_detect_requests_cycle(p_child bigint, p_parent bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_found boolean;

BEGIN

    ------------------------------------------------------------------

    -- Walk UP from proposed parent and see if we reach child

    ------------------------------------------------------------------

    WITH RECURSIVE edges AS (

        -- unify hierarchy edges

        SELECT

            ref_requests_record_id AS child_id,

            immediate_parent       AS parent_id

        FROM public.requests_services



        UNION ALL



        SELECT

            ref_requests_record_id,

            immediate_parent

        FROM public.requests_staffing

    ),

    ancestors AS (

        -- non-recursive term

        SELECT p_parent AS node_id



        UNION ALL



        -- recursive term (SINGLE reference)

        SELECT e.parent_id

        FROM ancestors a

        JOIN edges e

          ON e.child_id = a.node_id

    )

    SELECT true

    INTO v_found

    FROM ancestors

    WHERE node_id = p_child

    LIMIT 1;



    IF v_found THEN

        RAISE EXCEPTION

            'Hierarchy cycle detected: assigning % under % creates a loop',

            p_child,

            p_parent;

    END IF;

END;

$function$