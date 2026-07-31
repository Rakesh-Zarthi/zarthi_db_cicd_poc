CREATE OR REPLACE FUNCTION public.app_billing_roles_sign_off_step_1_planned_complete_via_actionab(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb, p_description text DEFAULT NULL::text)
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

-- Existing Step

------------------------------------------------------------------

v_actionable_id bigint;

v_step_status text;

v_request_subject bigint;







------------------------------------------------------------------

-- Metadata

------------------------------------------------------------------

v_sign_off_type text;

v_name text;

v_ms_id bigint;

v_quantity numeric;

v_available_quantity bigint;





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

IF COALESCE(v_sign_off_type, '') = '' THEN

    RAISE EXCEPTION 'signOffType is mandatory';

END IF;



IF COALESCE(v_name, '') = '' THEN

    RAISE EXCEPTION 'name is mandatory';

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

-- Resolve Step 1

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

  AND ast.step_no = 1;



IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION

        'Invalid Step 1';

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION

        'Step does not belong to supplied request';

END IF;



------------------------------------------------------------------

-- Planned Step Validation

------------------------------------------------------------------

IF v_step_status <> 'Planned' THEN

    RAISE EXCEPTION

        'Step 1 must be Planned';

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

            WHEN COALESCE(trim(p_description), '') <> ''

            THEN p_description

            ELSE actionable_description

        END

WHERE in_record_id = v_actionable_id;





------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    p_actionable_step_id,

  

    p_request_id,

    'STEP_1_PLANNED_SAVED'::text;



END;$function$