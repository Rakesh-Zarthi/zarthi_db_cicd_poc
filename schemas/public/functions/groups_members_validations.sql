CREATE OR REPLACE FUNCTION public.groups_members_validations()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_req_owner      bigint;

    v_group_type     text;

    v_status         text;



    v_owner_root     bigint;

    v_member_root    bigint;



    v_owner_path     bigint[];

    v_member_path    bigint[];



    v_required_path  bigint[];

    v_present        bigint[];

    v_missing        bigint[];



    v_has_members boolean;

    v_init_key    text;

BEGIN

    ------------------------------------------------------------------

    -- ≡ƒöô SYSTEM AUTO-EXPANSION (SAFE BYPASS)

    ------------------------------------------------------------------

    IF current_setting('app.system_group_expand', true) = 'true' THEN

        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;

    END IF;



    ------------------------------------------------------------------

    -- Resolve group owner + type

    ------------------------------------------------------------------

    SELECT g.ref_requests_in_record_id_group_owner,

           g.group_type

    INTO   v_req_owner,

           v_group_type

    FROM public.groups g

    WHERE g.in_record_id =

          COALESCE(NEW.ref_groups_in_record_id,

                   OLD.ref_groups_in_record_id);



    IF v_req_owner IS NULL THEN

        RAISE EXCEPTION

            'Group members validation failed. Group % not found.',

            COALESCE(NEW.ref_groups_in_record_id,

                     OLD.ref_groups_in_record_id);

    END IF;



    ------------------------------------------------------------------

    -- Init flag for actionable logic (unchanged)

    ------------------------------------------------------------------

    v_init_key := 'app.group_init_' ||

                  COALESCE(NEW.ref_groups_in_record_id,

                           OLD.ref_groups_in_record_id)::text;



    SELECT EXISTS (

        SELECT 1

        FROM public.groups_members gm

        WHERE gm.ref_groups_in_record_id =

              COALESCE(NEW.ref_groups_in_record_id,

                       OLD.ref_groups_in_record_id)

    )

    INTO v_has_members;



    IF TG_OP IN ('INSERT','UPDATE','DELETE') THEN

        IF v_has_members IS FALSE THEN

            PERFORM set_config(v_init_key, 'true', true);

        END IF;



        IF current_setting(v_init_key, true) IS DISTINCT FROM 'true' THEN

            IF NOT EXISTS (

                SELECT 1

                FROM public.actionables a

                WHERE a.request_subject     = v_req_owner

                  AND a.actionable_category = 'Collaborations'

                  AND a.actionable_name     = 'Update Group'

                  AND a.actionable_status   = 'Complete'

            ) THEN

                RAISE EXCEPTION

                    'Group update denied. Completed "Update Group" actionable required for request %.',

                    v_req_owner;

            END IF;



            PERFORM pg_advisory_xact_lock(

                (hashtext('update-group')::bigint << 32)

                | (v_req_owner & x'FFFFFFFF'::bigint)

            );

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- INSERT VALIDATIONS

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        -- Request must not be closed

        SELECT r.status

        INTO v_status

        FROM public.requests r

        WHERE r.in_record_id = NEW.ref_requests_in_record_id_members;



        IF v_status IN ('Close','Closed') THEN

            RAISE EXCEPTION

                'Insert denied. Request % is already "%".',

                NEW.ref_requests_in_record_id_members,

                v_status;

        END IF;



        ------------------------------------------------------------------

        -- SUB GROUP RULES

        ------------------------------------------------------------------

        IF v_group_type = 'Sub Group' THEN



            -- Roots

            SELECT root_parent, full_path

            INTO v_owner_root, v_owner_path

            FROM public.requests_hierarchy

            WHERE request_id = v_req_owner;



            SELECT root_parent, full_path

            INTO v_member_root, v_member_path

            FROM public.requests_hierarchy

            WHERE request_id = NEW.ref_requests_in_record_id_members;



            ------------------------------------------------------------------

            -- Γ£à Relationship rule: SAME TREE

            ------------------------------------------------------------------

            IF v_owner_root IS DISTINCT FROM v_member_root THEN

                RAISE EXCEPTION

                    'Insert denied. Member % is not related to Sub Group owner % (different hierarchy roots).',

                    NEW.ref_requests_in_record_id_members,

                    v_req_owner;

            END IF;



            ------------------------------------------------------------------

            -- ≡ƒöÆ CONTIGUITY CHECK (ONLY IF DESCENDANT OF OWNER)

            ------------------------------------------------------------------

            IF v_req_owner = ANY (v_member_path)

               AND NEW.ref_requests_in_record_id_members <> v_req_owner THEN



                -- owner ΓåÆ member slice

                SELECT array_agg(x ORDER BY ord)

                INTO v_required_path

                FROM unnest(v_member_path) WITH ORDINALITY u(x, ord)

                WHERE ord >= array_position(v_member_path, v_req_owner);



                SELECT array_agg(ref_requests_in_record_id_members)

                INTO v_present

                FROM public.groups_members

                WHERE ref_groups_in_record_id = NEW.ref_groups_in_record_id;



                SELECT array_agg(x)

                INTO v_missing

                FROM unnest(v_required_path) x

                WHERE NOT (x = ANY (v_present))

                  AND x <> NEW.ref_requests_in_record_id_members;



                IF v_missing IS NOT NULL THEN

                    RAISE EXCEPTION

                        'Insert denied. Sub Group hierarchy incomplete below owner %. Missing %.',

                        v_req_owner,

                        v_missing;

                END IF;

            END IF;

        END IF;



        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- UPDATE / DELETE (unchanged)

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN

        IF OLD.is_group_owner IS TRUE

           AND NEW.ref_requests_in_record_id_members

               IS DISTINCT FROM OLD.ref_requests_in_record_id_members THEN

            RAISE EXCEPTION

                'Update denied. Group owner member is immutable.';

        END IF;

        RETURN NEW;

    END IF;



    IF TG_OP = 'DELETE' THEN

        IF OLD.is_group_owner IS TRUE THEN

            RAISE EXCEPTION

                'Delete denied. Group owner member cannot be removed.';

        END IF;

        RETURN OLD;

    END IF;



    RETURN NEW;

END;

$function$