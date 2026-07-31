CREATE OR REPLACE FUNCTION public.app_billing_roles_sign_off_step_1_draft_via_actionable_step_v_0(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb, p_mode text, p_description text DEFAULT NULL::text)
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

-- Existing Records

------------------------------------------------------------------

v_actionable_id bigint;

 

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

IF upper(trim(p_mode)) = 'DRAFT' THEN

 

    IF p_json -> 'draftedData' IS NULL THEN

        RAISE EXCEPTION

            'draftedData is mandatory for DRAFT mode';

    END IF;

 

    IF COALESCE(p_json -> 'metadata', '{}'::jsonb) <> '{}'::jsonb THEN

        RAISE EXCEPTION

            'metadata must be null or {} for DRAFT mode';

    END IF;

 

ELSIF upper(trim(p_mode)) = 'PLANNED_DRAFT' THEN

 

    IF p_json -> 'draftedData' IS NULL

       OR p_json -> 'draftedData' = '{}'::jsonb

    THEN

        RAISE EXCEPTION

            'draftedData is mandatory for PLANNED_DRAFT mode';

    END IF;

 

    IF p_json -> 'metadata' IS NOT NULL

       AND p_json -> 'metadata' <> '{}'::jsonb

    THEN

        RAISE EXCEPTION

            'metadata must be null or {} for PLANNED_DRAFT mode';

    END IF;

 

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

    ast.ref_actionables_in_record_id

INTO

    v_actionable_id

FROM public.actionables_steps ast

JOIN public.actionables a

    ON a.in_record_id = ast.ref_actionables_in_record_id

WHERE ast.in_record_id = p_actionable_step_id

  AND ast.step_no = 1

  AND a.request_subject = p_request_id;

 

IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION

        'Invalid Step 1 for supplied request';

END IF;

 

------------------------------------------------------------------

-- Update Step Metadata

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

    'STEP_1_DRAFT_UPDATED'::text;

 

END;

$function$