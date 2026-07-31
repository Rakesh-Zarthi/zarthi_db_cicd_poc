CREATE OR REPLACE FUNCTION public.timesheet_001_005_validate_professional(p_row timesheet)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_step_owner_user_id    bigint;

    v_step_owner_request_id bigint;

    v_request_owner_id      bigint;

BEGIN



    ------------------------------------------------------------------

    -- 1) Fetch step ownership fields

    ------------------------------------------------------------------

    SELECT 

        s.ref_users_in_record_id_owner,

        s.ref_requests_in_record_id_assigned_to

    INTO

        v_step_owner_user_id,

        v_step_owner_request_id

    FROM public.actionables_steps s

    WHERE s.in_record_id = p_row.ref_actionables_steps_in_record_id;



    ------------------------------------------------------------------

    -- 2) CASE 1: Step owned by REQUEST (assigned_to)

    ------------------------------------------------------------------

    IF v_step_owner_request_id IS NOT NULL THEN



        SELECT r.owner

        INTO v_request_owner_id

        FROM public.requests r

        WHERE r.in_record_id = v_step_owner_request_id;



        IF v_request_owner_id IS NULL THEN

            RAISE EXCEPTION

                'Γ¥î Request owner missing for assigned request %.',

                v_step_owner_request_id;

        END IF;



        IF p_row.ref_users_in_record_id_professional <> v_request_owner_id THEN

            RAISE EXCEPTION

                'Γ¥î Timesheet user must match request owner (%).',

                v_request_owner_id;

        END IF;



    END IF;



    ------------------------------------------------------------------

    -- 3) CASE 2: Step owned by USER directly

    ------------------------------------------------------------------

    IF v_step_owner_user_id IS NOT NULL THEN



        IF p_row.ref_users_in_record_id_professional <> v_step_owner_user_id THEN

            RAISE EXCEPTION

                'Γ¥î Timesheet user must match step owner (%).',

                v_step_owner_user_id;

        END IF;



    END IF;



    ------------------------------------------------------------------

    -- 4) Safety: At least one ownership must exist

    ------------------------------------------------------------------

    IF v_step_owner_user_id IS NULL

       AND v_step_owner_request_id IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Step must have either user owner or request assignment.';

    END IF;



END;

$function$