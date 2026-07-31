CREATE OR REPLACE FUNCTION public.groups_members_expand_main_group()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_members bigint[];

    v_req     bigint;

BEGIN

    ------------------------------------------------------------------

    -- Only expand members for MAIN GROUP

    ------------------------------------------------------------------

    IF NEW.group_type <> 'Main Group' THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Defensive: Owner request must NOT be closed

    ------------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.requests r

        WHERE r.in_record_id = NEW.ref_requests_in_record_id_group_owner

          AND r.status IN ('Close', 'Closed')

    ) THEN

        RAISE EXCEPTION

            'Main Group expansion denied. Owner request % is already "%".',

            NEW.ref_requests_in_record_id_group_owner,

            (SELECT status

             FROM public.requests

             WHERE in_record_id = NEW.ref_requests_in_record_id_group_owner);

    END IF;



    ------------------------------------------------------------------

    -- ≡ƒöô SYSTEM-DRIVEN AUTO EXPANSION

    -- This bypasses ONLY "Update Group" validations

    ------------------------------------------------------------------

    PERFORM set_config('app.system_group_expand', 'true', true);



    ------------------------------------------------------------------

    -- Fetch ALL hierarchy members under the same root

    -- EXCLUDING closed requests

    -- INCLUDING the owner (will be deduplicated later)

    ------------------------------------------------------------------

    SELECT array_agg(rh.request_id ORDER BY rh.level)

    INTO v_members

    FROM public.requests_hierarchy rh

    JOIN public.requests r

      ON r.in_record_id = rh.request_id

    WHERE rh.root_parent = NEW.ref_requests_in_record_id_group_owner

      AND r.status NOT IN ('Close', 'Closed');



    ------------------------------------------------------------------

    -- Normalize NULL ΓåÆ empty array

    ------------------------------------------------------------------

    IF v_members IS NULL THEN

        v_members := ARRAY[]::bigint[];

    END IF;



    ------------------------------------------------------------------

    -- Insert GROUP OWNER (always required)

    ------------------------------------------------------------------

    INSERT INTO public.groups_members (

        ref_groups_in_record_id,

        ref_requests_in_record_id_members,

        is_group_owner

    )

    VALUES (

        NEW.in_record_id,

        NEW.ref_requests_in_record_id_group_owner,

        true

    )

    ON CONFLICT DO NOTHING;



    ------------------------------------------------------------------

    -- Insert ALL OTHER VALID MEMBERS

    ------------------------------------------------------------------

    FOREACH v_req IN ARRAY v_members LOOP

        IF v_req <> NEW.ref_requests_in_record_id_group_owner THEN

            INSERT INTO public.groups_members (

                ref_groups_in_record_id,

                ref_requests_in_record_id_members,

                is_group_owner

            )

            VALUES (

                NEW.in_record_id,

                v_req,

                false

            )

            ON CONFLICT DO NOTHING;

        END IF;

    END LOOP;



    ------------------------------------------------------------------

    -- Cleanup system flag (CRITICAL)

    ------------------------------------------------------------------

    PERFORM set_config('app.system_group_expand', 'false', true);



    RETURN NEW;



EXCEPTION

    WHEN OTHERS THEN

        -- Never leak system flag

        PERFORM set_config('app.system_group_expand', 'false', true);

        RAISE;

END;

$function$