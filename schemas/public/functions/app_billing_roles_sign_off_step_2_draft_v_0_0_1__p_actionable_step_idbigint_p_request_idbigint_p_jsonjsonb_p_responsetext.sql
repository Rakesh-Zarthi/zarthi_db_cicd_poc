CREATE OR REPLACE FUNCTION public.app_billing_roles_sign_off_step_2_draft_v_0_0_1(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb, p_response text DEFAULT NULL::text)
 RETURNS TABLE(actionable_id bigint, step_2_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Session

------------------------------------------------------------------

v_user_uuid uuid;

v_created_by bigint;



------------------------------------------------------------------

-- Step

------------------------------------------------------------------

v_actionable_id bigint;

v_step_status text;

v_request_subject bigint;



BEGIN



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_actionable_step_id IS NULL THEN

    RAISE EXCEPTION 'actionable_step_id is mandatory';

END IF;



IF p_request_id IS NULL THEN

    RAISE EXCEPTION 'request_id is mandatory';

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION 'json is mandatory';

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

-- Resolve Step 2

------------------------------------------------------------------

SELECT

    ast.ref_actionables_in_record_id,

    ast.status,

    a.request_subject

INTO

    v_actionable_id,

    v_step_status,

    v_request_subject

FROM public.actionables_steps ast

INNER JOIN public.actionables a

    ON a.in_record_id = ast.ref_actionables_in_record_id

WHERE ast.in_record_id = p_actionable_step_id

  AND ast.step_no = 2;



IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION

        'Invalid Step 2';

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION

        'Step does not belong to supplied request';

END IF;



IF v_step_status <> 'Open' THEN

    RAISE EXCEPTION

        'Step 2 must be Open';

END IF;



------------------------------------------------------------------

-- Update Step 2 Metadata

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    step_metadata = p_json

WHERE in_record_id = p_actionable_step_id;



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    p_actionable_step_id,

    p_request_id,

    'STEP_2_DRAFT_SAVED'::text;



END;

$function$