CREATE OR REPLACE FUNCTION public.groups_validate_sub_group()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_group_id    bigint;

    v_owner       bigint;



    v_owner_path  bigint[];

    v_member_path bigint[];



    v_lca         bigint;

    v_required    bigint[];

    v_present     bigint[];

    v_missing     bigint[];



    v_member_id   bigint;

BEGIN

    ------------------------------------------------------------------

    -- Resolve group id (groups OR groups_members trigger)

    ------------------------------------------------------------------

    IF TG_TABLE_NAME = 'groups' THEN

        v_group_id := NEW.in_record_id;

    ELSE

        v_group_id := NEW.ref_groups_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- Only validate Sub Groups

    ------------------------------------------------------------------

    SELECT ref_requests_in_record_id_group_owner

    INTO v_owner

    FROM public.groups

    WHERE in_record_id = v_group_id

      AND group_type = 'Sub Group';



    IF v_owner IS NULL THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Owner must exist as owner member

    ------------------------------------------------------------------

    IF NOT EXISTS (

        SELECT 1

        FROM public.groups_members

        WHERE ref_groups_in_record_id = v_group_id

          AND ref_requests_in_record_id_members = v_owner

          AND is_group_owner IS TRUE

    ) THEN

        RAISE EXCEPTION

            'Sub Group % invalid. Owner % missing as group owner.',

            v_group_id, v_owner;

    END IF;



    ------------------------------------------------------------------

    -- Fetch owner path

    ------------------------------------------------------------------

    SELECT full_path

    INTO v_owner_path

    FROM public.requests_hierarchy

    WHERE request_id = v_owner;



    ------------------------------------------------------------------

    -- Fetch present members once

    ------------------------------------------------------------------

    SELECT array_agg(ref_requests_in_record_id_members ORDER BY 1)

    INTO v_present

    FROM public.groups_members

    WHERE ref_groups_in_record_id = v_group_id;



    ------------------------------------------------------------------

    -- Validate EACH member strictly

    ------------------------------------------------------------------

    FOR v_member_id IN

        SELECT ref_requests_in_record_id_members

        FROM public.groups_members

        WHERE ref_groups_in_record_id = v_group_id

    LOOP

        SELECT full_path

        INTO v_member_path

        FROM public.requests_hierarchy

        WHERE request_id = v_member_id;



        ------------------------------------------------------------------

        -- Find LCA (FIXED ord ambiguity)

        ------------------------------------------------------------------

        SELECT o.x

        INTO v_lca

        FROM unnest(v_owner_path)  WITH ORDINALITY o(x, o_ord)

        JOIN unnest(v_member_path) WITH ORDINALITY m(x, m_ord)

          ON o.x = m.x

        ORDER BY o.o_ord DESC

        LIMIT 1;



        IF v_lca IS NULL THEN

            RAISE EXCEPTION

                'Sub Group % invalid. No lineage connection between owner % and member %.',

                v_group_id, v_owner, v_member_id;

        END IF;



        ------------------------------------------------------------------

        -- Build REQUIRED PATH: owner ΓåÆ LCA ΓåÆ member

        ------------------------------------------------------------------

        SELECT array_agg(DISTINCT x ORDER BY x)

        INTO v_required

        FROM (

            -- owner ΓåÆ LCA

            SELECT o.x

            FROM unnest(v_owner_path) WITH ORDINALITY o(x, o_ord)

            WHERE o.o_ord >= array_position(v_owner_path, v_lca)



            UNION ALL



            -- LCA ΓåÆ member

            SELECT m.x

            FROM unnest(v_member_path) WITH ORDINALITY m(x, m_ord)

            WHERE m.m_ord >= array_position(v_member_path, v_lca)

        ) s;



        ------------------------------------------------------------------

        -- Detect missing intermediates

        ------------------------------------------------------------------

        SELECT array_agg(x)

        INTO v_missing

        FROM unnest(v_required) x

        WHERE NOT (x = ANY (v_present));



        IF v_missing IS NOT NULL THEN

            RAISE EXCEPTION

                'Sub Group % invalid. Missing mandatory lineage nodes % between owner % and member %.',

                v_group_id, v_missing, v_owner, v_member_id;

        END IF;

    END LOOP;



    RETURN NEW;

END;

$function$