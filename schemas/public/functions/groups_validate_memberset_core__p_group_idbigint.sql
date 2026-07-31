CREATE OR REPLACE FUNCTION public.groups_validate_memberset_core(p_group_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    ------------------------------------------------------------------

    -- CORE ATTRIBUTES

    ------------------------------------------------------------------

    v_owner        BIGINT;

    v_group_type   TEXT;

    v_root_problem BIGINT;



    ------------------------------------------------------------------

    -- MEMBERSHIP STATE

    ------------------------------------------------------------------

    v_members      BIGINT[];

    v_anchor       BIGINT;

    v_bad          BIGINT[];

    v_deepest      BIGINT;

    v_missing      BIGINT[];

BEGIN

    ------------------------------------------------------------------

    -- 1∩╕ÅΓâú LOAD GROUP OWNER AND TYPE

    ------------------------------------------------------------------

    SELECT

        g.ref_requests_in_record_id_group_owner,

        g.group_type

    INTO

        v_owner,

        v_group_type

    FROM public.groups g

    WHERE g.in_record_id = p_group_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid group_id %. Expected groups.in_record_id.',

            p_group_id;

    END IF;



    IF v_owner IS NULL THEN

        RAISE EXCEPTION

            'Group % has no owner assigned.',

            p_group_id;

    END IF;



    v_anchor := v_owner;



    ------------------------------------------------------------------

    -- 2∩╕ÅΓâú LOAD GROUP MEMBERS

    ------------------------------------------------------------------

    SELECT array_agg(ref_requests_in_record_id_members ORDER BY 1)

    INTO v_members

    FROM public.groups_members

    WHERE ref_groups_in_record_id = p_group_id;



    IF v_members IS NULL THEN

        RAISE EXCEPTION

            'Group % has no members.',

            p_group_id;

    END IF;



    ------------------------------------------------------------------

    -- 3∩╕ÅΓâú OWNER MUST BE EXPLICIT MEMBER

    ------------------------------------------------------------------

    IF NOT (v_owner = ANY (v_members)) THEN

        RAISE EXCEPTION

            'Group % invalid. Owner % must be a member.',

            p_group_id,

            v_owner;

    END IF;



    ------------------------------------------------------------------

    -- 4∩╕ÅΓâú IDENTIFY ROOT PROBLEM (SCOPE LIMITER)

    ------------------------------------------------------------------

    SELECT rh.root_parent

    INTO v_root_problem

    FROM public.requests_hierarchy rh

    WHERE rh.request_id = v_anchor;



    IF v_root_problem IS NULL THEN

        RAISE EXCEPTION

            'Unable to determine root Problem for owner %.',

            v_anchor;

    END IF;



    ------------------------------------------------------------------

    -- 5∩╕ÅΓâú BUILD SCOPED HIERARCHY (FAST, BOUNDED)

    ------------------------------------------------------------------

    DROP TABLE IF EXISTS tmp_rh;



    CREATE TEMP TABLE tmp_rh

    ON COMMIT DROP

    AS

    WITH RECURSIVE tree AS (

        -- root

        SELECT

            r.in_record_id        AS request_id,

            NULL::BIGINT          AS parent_id,

            1                     AS level,

            ARRAY[r.in_record_id] AS full_path

        FROM public.requests r

        WHERE r.in_record_id = v_root_problem



        UNION ALL



        -- children

        SELECT

            e.child_id,

            e.immediate_parent,

            t.level + 1,

            t.full_path || e.child_id

        FROM tree t

        JOIN (

            SELECT rs.immediate_parent,

                   rs.ref_requests_record_id AS child_id

            FROM public.requests_services rs



            UNION ALL



            SELECT rf.immediate_parent,

                   rf.ref_requests_record_id

            FROM public.requests_staffing rf

        ) e

          ON e.immediate_parent = t.request_id

        WHERE NOT (e.child_id = ANY (t.full_path))

    )

    SELECT

        request_id,

        parent_id,

        level,

        full_path

    FROM tree;



    CREATE INDEX ON tmp_rh (request_id);

    CREATE INDEX ON tmp_rh USING GIN (full_path);



    ------------------------------------------------------------------

    -- 6∩╕ÅΓâú BIDIRECTIONAL CONNECTIVITY VALIDATION

    ------------------------------------------------------------------

    WITH

    member_paths AS (

        SELECT request_id, full_path

        FROM tmp_rh

        WHERE request_id = ANY (v_members)

    ),

    owner_path AS (

        SELECT full_path

        FROM tmp_rh

        WHERE request_id = v_anchor

    )

    SELECT array_agg(mp.request_id)

    INTO v_bad

    FROM member_paths mp

    CROSS JOIN owner_path op

    WHERE NOT (

        mp.full_path @> ARRAY[v_anchor]      -- descendant

        OR

        op.full_path @> ARRAY[mp.request_id] -- ancestor

    );



    IF v_bad IS NOT NULL THEN

        RAISE EXCEPTION

            'Group % invalid. Members % are not connected to owner %.',

            p_group_id,

            v_bad,

            v_owner;

    END IF;



    ------------------------------------------------------------------

    -- 7∩╕ÅΓâú SUB GROUP RULE: NO SKIPPED INTERMEDIATES

    ------------------------------------------------------------------

    IF v_group_type = 'Sub Group' THEN



        ------------------------------------------------------------------

        -- 7A) DEEPEST MEMBER

        ------------------------------------------------------------------

        SELECT request_id

        INTO v_deepest

        FROM tmp_rh

        WHERE request_id = ANY (v_members)

        ORDER BY level DESC

        LIMIT 1;



        ------------------------------------------------------------------

        -- 7B) CONTIGUOUS CHAIN VALIDATION (FIXED LCA)

        ------------------------------------------------------------------

        WITH

        owner_path AS (

            SELECT full_path

            FROM tmp_rh

            WHERE request_id = v_anchor

        ),

        deepest_path AS (

            SELECT full_path

            FROM tmp_rh

            WHERE request_id = v_deepest

        ),

        lca AS (

            SELECT o.node

            FROM unnest((SELECT full_path FROM owner_path))

                 WITH ORDINALITY AS o(node, pos)

            WHERE o.node IN (

                SELECT unnest((SELECT full_path FROM deepest_path))

            )

            ORDER BY o.pos DESC

            LIMIT 1

        ),

        full_chain AS (

            -- owner ΓåÆ LCA

            SELECT (SELECT full_path FROM owner_path)[i] AS node

            FROM generate_subscripts(

                     (SELECT full_path FROM owner_path), 1

                 ) i

            WHERE i >= array_position(

                      (SELECT full_path FROM owner_path),

                      (SELECT node FROM lca)

                  )



            UNION ALL



            -- LCA ΓåÆ deepest (excluding LCA)

            SELECT (SELECT full_path FROM deepest_path)[i]

            FROM generate_subscripts(

                     (SELECT full_path FROM deepest_path), 1

                 ) i

            WHERE i >

                  array_position(

                      (SELECT full_path FROM deepest_path),

                      (SELECT node FROM lca)

                  )

        )

        SELECT array_agg(node)

        INTO v_missing

        FROM full_chain

        WHERE NOT (node = ANY (v_members));



        IF v_missing IS NOT NULL THEN

            RAISE EXCEPTION

                'Sub Group % invalid. Missing intermediate members %.',

                p_group_id,

                v_missing;

        END IF;



    END IF;



END;

$function$