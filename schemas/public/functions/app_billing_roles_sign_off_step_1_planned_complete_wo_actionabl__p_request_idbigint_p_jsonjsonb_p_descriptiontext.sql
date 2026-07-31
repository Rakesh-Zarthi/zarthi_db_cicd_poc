CREATE OR REPLACE FUNCTION public.app_billing_roles_sign_off_step_1_planned_complete_wo_actionabl(p_request_id bigint, p_json jsonb, p_description text DEFAULT NULL::text)
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

-- Metadata

------------------------------------------------------------------

v_sign_off_type text;

v_name text;

v_ms_id bigint;

v_quantity numeric;

v_available_quantity bigint;



------------------------------------------------------------------

-- Output

------------------------------------------------------------------

v_actionable_id bigint;

v_step_1_id bigint;



BEGIN



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_request_id IS NULL THEN

    RAISE EXCEPTION 'request_id is mandatory';

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION 'json is mandatory';

END IF;





------------------------------------------------------------------

-- Validate JSON Structure

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

        'draftedData must be null or {}';

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

-- Create Step 1 (Planned)

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

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    v_step_1_id,

    p_request_id,

    'STEP_1_PLANNED_SAVED'::text;



END;$function$