CREATE OR REPLACE FUNCTION public.app_orders_cancel_micros_quantity_step_1_planned_complete_via_a(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb)
 RETURNS TABLE(actionable_id bigint, step_1_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$



DECLARE



    v_user_uuid uuid;

    v_created_by bigint;



    v_actionable_id bigint;

    v_step_no integer;

    v_step_status text;

    v_request_subject bigint;



BEGIN



    ------------------------------------------------------------------

    -- Mandatory Validation

    ------------------------------------------------------------------

    IF p_actionable_step_id IS NULL THEN

        RAISE EXCEPTION

            'actionable_step_id is mandatory';

    END IF;



    IF p_request_id IS NULL THEN

        RAISE EXCEPTION

            'request_id is mandatory';

    END IF;



    IF p_json IS NULL THEN

        RAISE EXCEPTION

            'json is mandatory';

    END IF;



------------------------------------------------------------------

-- JSON Validation

------------------------------------------------------------------

IF p_json -> 'metadata' IS NULL

   OR p_json -> 'metadata' = '{}'::jsonb

THEN

    RAISE EXCEPTION

        'metadata is mandatory';

END IF;



IF p_json -> 'draftedData' IS NOT NULL

   AND p_json -> 'draftedData' <> '{}'::jsonb

THEN

    RAISE EXCEPTION

        'draftedData must be empty';

END IF;

    ------------------------------------------------------------------

    -- Resolve Session User

    ------------------------------------------------------------------

    v_user_uuid :=

        current_setting(

            'app.CURRENT_USER_ID',

            true

        )::uuid;



    SELECT u.in_record_id

    INTO v_created_by

    FROM public.users u

    WHERE u.user_id = v_user_uuid;



    IF v_created_by IS NULL THEN

        RAISE EXCEPTION

            'Unable to resolve session user';

    END IF;



    ------------------------------------------------------------------

    -- Resolve Step

    ------------------------------------------------------------------

    SELECT

        ast.ref_actionables_in_record_id,

        ast.step_no,

        ast.status,

        a.request_subject

    INTO

        v_actionable_id,

        v_step_no,

        v_step_status,

        v_request_subject

    FROM public.actionables_steps ast

    INNER JOIN public.actionables a

        ON a.in_record_id =

           ast.ref_actionables_in_record_id

    WHERE ast.in_record_id =

          p_actionable_step_id;



    IF v_actionable_id IS NULL THEN

        RAISE EXCEPTION

            'Invalid actionable step id';

    END IF;



    IF v_request_subject <> p_request_id THEN

        RAISE EXCEPTION

            'Request mismatch';

    END IF;



    IF v_step_no <> 1 THEN

        RAISE EXCEPTION

            'Only Step 1 supported';

    END IF;



    IF v_step_status NOT IN ('Planned') THEN

        RAISE EXCEPTION

            'Step must be Planned';

    END IF;



    ------------------------------------------------------------------

    -- Complete Step 1

    ------------------------------------------------------------------

    UPDATE public.actionables_steps

    SET

        status = 'Planned',

        step_metadata = p_json

    WHERE in_record_id =

          p_actionable_step_id;





    ------------------------------------------------------------------

    -- Return

    ------------------------------------------------------------------

    RETURN QUERY

    SELECT

        v_actionable_id,

        p_actionable_step_id,

        p_request_id,

        'STEP_1_PLANNED';



END;

$function$