CREATE OR REPLACE FUNCTION public.app_billing_roles_sign_off_step_1_draft_wo_actionable_step_v_0_(p_request_id bigint, p_json jsonb, p_mode text, p_description text DEFAULT NULL::text)
 RETURNS TABLE(actionable_id bigint, step_1_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Session

------------------------------------------------------------------

v_user_uuid uuid;

v_created_by bigint;



------------------------------------------------------------------

-- Control

------------------------------------------------------------------

v_mode text;



------------------------------------------------------------------

-- Output

------------------------------------------------------------------

v_actionable_id bigint;

v_step_1_id bigint;



BEGIN



------------------------------------------------------------------

-- Normalize Mode

------------------------------------------------------------------

v_mode := upper(trim(p_mode));



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_request_id IS NULL THEN

    RAISE EXCEPTION 'request_id is mandatory';

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION 'json is mandatory';

END IF;



IF p_mode IS NULL THEN

    RAISE EXCEPTION 'mode is mandatory';

END IF;



------------------------------------------------------------------

-- Validate Mode

------------------------------------------------------------------

IF v_mode NOT IN (

    'DRAFT',

    'PLANNED_DRAFT'

)

THEN

    RAISE EXCEPTION

        'mode must be DRAFT or PLANNED_DRAFT';

END IF;



------------------------------------------------------------------

-- Validate JSON Structure

------------------------------------------------------------------

IF v_mode = 'DRAFT'

AND p_json -> 'draftedData' IS NULL

THEN

    RAISE EXCEPTION

        'draftedData is mandatory for DRAFT mode';

END IF;



IF v_mode = 'PLANNED_DRAFT'

AND (

    p_json -> 'draftedData' IS NULL

    OR p_json -> 'draftedData' = '{}'::jsonb

)

THEN

    RAISE EXCEPTION

        'draftedData is mandatory for PLANNED_DRAFT mode';

END IF;



IF v_mode = 'PLANNED_DRAFT'

AND p_json -> 'metadata' IS NOT NULL

AND p_json -> 'metadata' <> '{}'::jsonb

THEN

    RAISE EXCEPTION

        'metadata must be null or {} for PLANNED_DRAFT mode';

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

-- Validate Roles Request

------------------------------------------------------------------

IF NOT EXISTS (

    SELECT 1

    FROM public.requests r

    WHERE r.in_record_id = p_request_id

      AND r.module = 'Roles'

)

THEN

    RAISE EXCEPTION

        'Invalid Roles request';

END IF;



------------------------------------------------------------------

-- Create Actionable

------------------------------------------------------------------

INSERT INTO public.actionables (

    actionable_name,

    actionable_category,

    request_subject,

    ref_requests_in_record_id,

    actionable_description,

    created_by,

    actionable_creation_time

)

VALUES (

    'Sign Off',

    'Billing',

    p_request_id,

    p_request_id,

    p_description,

    v_created_by,

    now()

)

RETURNING in_record_id

INTO v_actionable_id;



------------------------------------------------------------------

-- Create Step 1

------------------------------------------------------------------

INSERT INTO public.actionables_steps (

    ref_actionables_in_record_id,

    ref_requests_in_record_id_assigned_to,

    step_no,

    status,

    step_metadata

)

VALUES (

    v_actionable_id,

    p_request_id,

    1,

    'Planned',

    p_json

)

RETURNING in_record_id

INTO v_step_1_id;



------------------------------------------------------------------

-- Convert to Draft if required

------------------------------------------------------------------

IF v_mode = 'DRAFT' THEN



    UPDATE public.actionables_steps

    SET status = 'Draft'

    WHERE in_record_id = v_step_1_id;



END IF;



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    v_step_1_id,

    p_request_id,

    CASE

        WHEN v_mode = 'DRAFT'

            THEN 'STEP_1_DRAFT_SAVED'

        ELSE

            'STEP_1_PLANNED_DRAFT_SAVED'

    END;



END;

$function$