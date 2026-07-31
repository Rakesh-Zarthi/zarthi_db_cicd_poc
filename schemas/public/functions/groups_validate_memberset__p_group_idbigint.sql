CREATE OR REPLACE FUNCTION public.groups_validate_memberset(p_group_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_owner      bigint;

    v_group_type text;

    v_members    bigint[];

    v_anchor     bigint;

    v_bad        bigint[];

BEGIN

    ------------------------------------------------------------------

    -- Load group context

    ------------------------------------------------------------------

    SELECT g.ref_requests_in_record_id_group_owner,

           g.group_type

    INTO   v_owner,

           v_group_type

    FROM public.groups g

    WHERE g.in_record_id = p_group_id;



    IF v_owner IS NULL THEN

        RAISE EXCEPTION 'Group % not found.', p_group_id;

    END IF;



    ------------------------------------------------------------------

    -- Collect ALL members (commit-time snapshot)

    ------------------------------------------------------------------

    SELECT array_agg(ref_requests_in_record_id_members ORDER BY 1)

    INTO v_members

    FROM public.groups_members

    WHERE ref_groups_in_record_id = p_group_id;



    IF v_members IS NULL THEN

        RAISE EXCEPTION

            'Group % has no members. At least one member is required.',

            p_group_id;

    END IF;



    ------------------------------------------------------------------

    -- Owner MUST be present

    ------------------------------------------------------------------

    IF NOT v_owner = ANY (v_members) THEN

        RAISE EXCEPTION

            'Group % invalid. Owner % must be a group member.',

            p_group_id,

            v_owner;

    END IF;



    ------------------------------------------------------------------

    -- Choose anchor = owner

    ------------------------------------------------------------------

    v_anchor := v_owner;



    ------------------------------------------------------------------

    -- 1∩╕ÅΓâú Connectivity check (ALL members connected)

    ------------------------------------------------------------------

    SELECT array_agg(m)

    INTO v_bad

    FROM unnest(v_members) m

    WHERE public.groups_members_connected_path(v_anchor, m) IS NULL;



    IF v_bad IS NOT NULL THEN

        RAISE EXCEPTION

            'Group % invalid. Members % are not connected to owner %.',

            p_group_id,

            v_bad,

            v_owner;

    END IF;



    ------------------------------------------------------------------

    -- 2∩╕ÅΓâú Sub Group hierarchy completeness

    ------------------------------------------------------------------

    IF v_group_type = 'Sub Group' THEN



        -- Find deepest member

        DECLARE

            v_deepest bigint;

            v_path    bigint[];

            v_missing bigint[];

        BEGIN

            SELECT rh.request_id

            INTO v_deepest

            FROM public.requests_hierarchy rh

            WHERE rh.request_id = ANY (v_members)

            ORDER BY rh.level DESC

            LIMIT 1;



            SELECT public.groups_members_connected_path(v_anchor, v_deepest)

            INTO v_path;



            -- All nodes in path must exist in members

            SELECT array_agg(x)

            INTO v_missing

            FROM unnest(v_path) x

            WHERE NOT x = ANY (v_members);



            IF v_missing IS NOT NULL THEN

                RAISE EXCEPTION

                    'Sub Group % invalid. Missing intermediate members %.',

                    p_group_id,

                    v_missing;

            END IF;

        END;

    END IF;

END;

$function$