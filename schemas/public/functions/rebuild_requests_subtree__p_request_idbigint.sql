CREATE OR REPLACE FUNCTION public.rebuild_requests_subtree(p_request_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_new_root bigint;

BEGIN

    ------------------------------------------------------------------

    -- 1) Resolve authoritative Problem root

    ------------------------------------------------------------------

    SELECT root_parent

      INTO v_new_root

      FROM public.requests_services

     WHERE ref_requests_record_id = p_request_id;



    IF NOT FOUND THEN

        SELECT root_parent

          INTO v_new_root

          FROM public.requests_staffing

         WHERE ref_requests_record_id = p_request_id;

    END IF;



    IF v_new_root IS NULL THEN

        RAISE EXCEPTION

            'Cannot rebuild subtree: root_parent missing for request_id %',

            p_request_id;

    END IF;



    ------------------------------------------------------------------

    -- 2) Build subtree (safe for repeated trigger calls)

    ------------------------------------------------------------------

    CREATE TEMP TABLE IF NOT EXISTS tmp_subtree_nodes (

    node_id bigint PRIMARY KEY

    ) ON COMMIT DROP;



    TRUNCATE tmp_subtree_nodes;



    WITH RECURSIVE edges AS (

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

    subtree AS (

        SELECT p_request_id AS node_id



        UNION ALL



        SELECT e.child_id

        FROM subtree s

        JOIN edges e

          ON e.parent_id = s.node_id

    )

    INSERT INTO tmp_subtree_nodes (node_id)

    SELECT node_id FROM subtree;



    ------------------------------------------------------------------

    -- 3) Update SERVICES

    ------------------------------------------------------------------

    UPDATE public.requests_services

       SET root_parent = v_new_root

     WHERE ref_requests_record_id IN (

           SELECT node_id FROM tmp_subtree_nodes

     );



    ------------------------------------------------------------------

    -- 4) Update STAFFING

    ------------------------------------------------------------------

    UPDATE public.requests_staffing

       SET root_parent = v_new_root

     WHERE ref_requests_record_id IN (

           SELECT node_id FROM tmp_subtree_nodes

     );

END;

$function$