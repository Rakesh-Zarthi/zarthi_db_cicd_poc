CREATE OR REPLACE FUNCTION public.app_billing_roles_sign_off_step_1_complete_via_actionable_step_(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb, p_step_2_json jsonb, p_description text DEFAULT NULL::text)
 RETURNS TABLE(actionable_id bigint, step_1_id bigint, step_2_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Session

------------------------------------------------------------------

v_user_uuid uuid;

v_created_by bigint;



------------------------------------------------------------------

-- Existing Step

------------------------------------------------------------------

v_actionable_id bigint;

v_step_status text;

v_request_subject bigint;



------------------------------------------------------------------

-- Parent Request

------------------------------------------------------------------

v_immediate_parent_request_id bigint;



------------------------------------------------------------------

-- Metadata

------------------------------------------------------------------

v_sign_off_type text;

v_name text;

v_ms_id bigint;

v_quantity numeric;



------------------------------------------------------------------

-- Step 2

------------------------------------------------------------------

v_step_2_id bigint;



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

        'draftedData must be empty';

END IF;



------------------------------------------------------------------

-- Extract Mandatory Fields

------------------------------------------------------------------

v_sign_off_type :=

    trim(

        p_json -> 'metadata' ->> 'signOffType'

    );



v_name :=

    trim(

        p_json -> 'metadata' ->> 'name'

    );



v_ms_id :=

    NULLIF(

        p_json -> 'metadata' ->> 'msId',

        ''

    )::bigint;



v_quantity :=

    NULLIF(

        p_json -> 'metadata' ->> 'quantity',

        ''

    )::numeric;



------------------------------------------------------------------

-- Validate Mandatory Fields

------------------------------------------------------------------

IF COALESCE(v_sign_off_type,'') = '' THEN

    RAISE EXCEPTION 'signOffType is mandatory';

END IF;



IF COALESCE(v_name,'') = '' THEN

    RAISE EXCEPTION 'name is mandatory';

END IF;



IF v_ms_id IS NULL THEN

    RAISE EXCEPTION 'msId is mandatory';

END IF;



IF v_quantity IS NULL THEN

    RAISE EXCEPTION 'quantity is mandatory';

END IF;





IF v_quantity <= 0

OR v_quantity <> floor(v_quantity)

THEN

    RAISE EXCEPTION

        'quantity must be a positive whole number';

END IF;





------------------------------------------------------------------

-- Usage Validation

-- Requested quantity must be available in Delivery In Progress

------------------------------------------------------------------

IF (

    SELECT count(*)

    FROM usage u

    WHERE u.ref_requests_in_record_id = p_request_id

      AND u.ref_services_sku_in_record_id = v_ms_id

      AND u.status = 'Delivery In Progress'

) < v_quantity

THEN

    RAISE EXCEPTION

        'Requested quantity % exceeds available Delivery In Progress quantity for microservice %',

        v_quantity,

        v_ms_id;

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

    ast.status,

    a.request_subject

INTO

    v_actionable_id,

    v_step_status,

    v_request_subject

FROM public.actionables_steps ast

JOIN public.actionables a

    ON a.in_record_id = ast.ref_actionables_in_record_id

WHERE ast.in_record_id = p_actionable_step_id

  AND ast.step_no = 1;



IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION

        'Invalid Step 1';

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION

        'Step does not belong to supplied request';

END IF;



IF v_step_status NOT IN (

    'Draft',

    'Planned'

)

THEN

    RAISE EXCEPTION

        'Step 1 must be Draft or Planned';

END IF;



------------------------------------------------------------------

-- Resolve Parent Request

------------------------------------------------------------------

SELECT r.ref_requests_in_record_id_immediate_parent

INTO v_immediate_parent_request_id

FROM public.requests r

WHERE r.in_record_id = p_request_id;



IF v_immediate_parent_request_id IS NULL THEN

    RAISE EXCEPTION

        'Immediate parent request not found';

END IF;



------------------------------------------------------------------

-- Update Step 1 Metadata

------------------------------------------------------------------

UPDATE public.actionables_steps

SET step_metadata = p_json

WHERE in_record_id = p_actionable_step_id;



------------------------------------------------------------------

-- Update Actionable

------------------------------------------------------------------

UPDATE public.actionables

SET

    actionable_description =

        CASE

            WHEN COALESCE(trim(p_description),'') <> ''

            THEN p_description

            ELSE actionable_description

        END

WHERE in_record_id = v_actionable_id;



------------------------------------------------------------------

-- Create Step 2 First

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

    v_immediate_parent_request_id,

    2,

    'Open',

    p_step_2_json

)

RETURNING in_record_id

INTO v_step_2_id;



------------------------------------------------------------------

-- Complete Step 1

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    status = 'Complete',

    ref_users_in_record_id_completed_by = v_created_by

WHERE in_record_id = p_actionable_step_id;



------------------------------------------------------------------

-- Reserve Usage Records For Sign Off

-- Oldest X records move to Pending Sign-off

------------------------------------------------------------------

UPDATE usage u

SET status = 'Pending Sign-Off'

WHERE u.in_record_id IN (

    SELECT uu.in_record_id

    FROM usage uu

    WHERE uu.ref_requests_in_record_id = p_request_id

      AND uu.ref_services_sku_in_record_id = v_ms_id

      AND uu.status = 'Delivery In Progress'

    ORDER BY uu.in_record_id

    LIMIT v_quantity

);

------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    p_actionable_step_id,

    v_step_2_id,

    p_request_id,

    'STEP_1_COMPLETE';



END;

$function$