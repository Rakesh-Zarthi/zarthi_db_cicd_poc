CREATE OR REPLACE FUNCTION public.app_billing_roles_sign_off_step_3_complete_v_0_0_1(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb, p_response text)
 RETURNS TABLE(actionable_id bigint, step_3_id bigint, request_id bigint, workflow_state text)
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



IF COALESCE(trim(p_response), '') = '' THEN

    RAISE EXCEPTION 'response is mandatory';

END IF;



------------------------------------------------------------------

-- Validate Response

------------------------------------------------------------------

IF p_response NOT IN (

    'Delivered',

    'Not Delivered'

)

THEN

    RAISE EXCEPTION

        'response must be Delivered or Not Delivered';

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

-- Resolve Step 3

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

  AND ast.step_no = 3;



IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION

        'Invalid Step 3';

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION

        'Step does not belong to supplied request';

END IF;



IF v_step_status <> 'Open' THEN

    RAISE EXCEPTION

        'Step 3 must be Open';

END IF;





------------------------------------------------------------------

-- Complete Step 3

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    status = 'Complete',

    delivery_decision = p_response,

    step_metadata = p_json,

    ref_users_in_record_id_completed_by = v_created_by

WHERE in_record_id = p_actionable_step_id;



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    p_actionable_step_id,

    p_request_id,

    'STEP_3_COMPLETE'::text;



END;

$function$