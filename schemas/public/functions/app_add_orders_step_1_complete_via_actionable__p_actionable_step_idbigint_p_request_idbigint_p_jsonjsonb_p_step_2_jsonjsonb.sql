CREATE OR REPLACE FUNCTION public.app_add_orders_step_1_complete_via_actionable(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb, p_step_2_json jsonb)
 RETURNS TABLE(actionable_id bigint, step_1_id bigint, step_2_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Session User

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

-- Step 2

------------------------------------------------------------------

v_step_2_id bigint;



------------------------------------------------------------------

-- Usage Creation Result

------------------------------------------------------------------

v_usage_result boolean;



BEGIN



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_actionable_step_id IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][VALIDATION][ERROR] actionable_step_id is mandatory';

END IF;



IF p_request_id IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][VALIDATION][ERROR] request_id is mandatory';

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][VALIDATION][ERROR] json is mandatory';

END IF;



------------------------------------------------------------------

-- Metadata Validation

------------------------------------------------------------------

IF p_json -> 'metadata' IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][VALIDATION][ERROR] metadata is mandatory';

END IF;



IF COALESCE(

       p_json -> 'draftedData',

       '{}'::jsonb

   ) <> '{}'::jsonb

THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][VALIDATION][ERROR] draftedData must be null or {}';

END IF;



IF COALESCE(

       jsonb_array_length(

           COALESCE(

               p_json -> 'metadata' -> 'microservice',

               '[]'::jsonb

           )

       ),

       0

   ) = 0

AND

   COALESCE(

       jsonb_array_length(

           COALESCE(

               p_json -> 'metadata' -> 'hours',

               '[]'::jsonb

           )

       ),

       0

   ) = 0

THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][VALIDATION][ERROR] At least one Microservice or Hours entry is required';

END IF;



------------------------------------------------------------------

-- Resolve Session User

------------------------------------------------------------------

v_user_uuid := current_setting('app.CURRENT_USER_ID', true)::uuid;



SELECT u.in_record_id

INTO v_created_by

FROM public.users u

WHERE u.user_id = v_user_uuid;



IF v_created_by IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][SESSION][ERROR] Unable to resolve session user';

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

JOIN public.actionables a

    ON a.in_record_id = ast.ref_actionables_in_record_id

WHERE ast.in_record_id = p_actionable_step_id

  AND ast.step_no = 1;



IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][STEP_RESOLVE][ERROR] Invalid Step 1 id %',

        p_actionable_step_id;

END IF;



------------------------------------------------------------------

-- Validate Request

------------------------------------------------------------------

IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][REQUEST_VALIDATE][ERROR] Step 1 does not belong to request %',

        p_request_id;

END IF;



------------------------------------------------------------------

-- Validate Status

------------------------------------------------------------------

IF v_step_status NOT IN ('Draft', 'Planned') THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][STEP_VALIDATE][ERROR] Step 1 status must be Draft or Planned. Current status = %',

        v_step_status;

END IF;



------------------------------------------------------------------

-- Update Step 1 Metadata

------------------------------------------------------------------

UPDATE public.actionables_steps

SET step_metadata = p_json

WHERE in_record_id = p_actionable_step_id;



------------------------------------------------------------------

-- Update Actionable Metadata

------------------------------------------------------------------

UPDATE public.actionables

SET action_metadata = p_json

WHERE in_record_id = v_actionable_id;



------------------------------------------------------------------

-- Resolve Immediate Parent

------------------------------------------------------------------

SELECT r.ref_requests_in_record_id_immediate_parent

INTO v_immediate_parent_request_id

FROM public.requests r

WHERE r.in_record_id = p_request_id;



IF v_immediate_parent_request_id IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][PARENT_RESOLVE][ERROR] Immediate parent request not found';

END IF;



------------------------------------------------------------------

-- Prevent Duplicate Step 2

------------------------------------------------------------------

IF EXISTS (

    SELECT 1

    FROM public.actionables_steps ast

    WHERE ast.ref_actionables_in_record_id = v_actionable_id

      AND ast.step_no = 2

)

THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_VIA][STEP_2_CREATE][ERROR] Step 2 already exists for actionable %',

        v_actionable_id;

END IF;



------------------------------------------------------------------

-- Create Step 2

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

-- Create Usage Records

------------------------------------------------------------------

SELECT public.app_add_orders_02_create_usage(v_actionable_id)

INTO v_usage_result;



IF NOT v_usage_result THEN

    RAISE EXCEPTION '[STEP_1_COMPLETE_WO][USAGE_CREATE][ERROR] Failed to create usage records for actionable %', v_actionable_id;

END IF; 



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    p_actionable_step_id,

    v_step_2_id,

    p_request_id,

    'STEP_1_COMPLETE'::text;



END;

$function$