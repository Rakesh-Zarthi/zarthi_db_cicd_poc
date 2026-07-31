CREATE OR REPLACE FUNCTION public.app_add_orders_step_1_complete_wo_actionable(p_request_id bigint, p_json jsonb, p_step_2_json jsonb)
 RETURNS orders_add_microservice_quantity_response
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Session User

------------------------------------------------------------------

v_user_uuid uuid;

v_created_by bigint;



------------------------------------------------------------------

-- Request

------------------------------------------------------------------

v_module text;

v_immediate_parent_request_id bigint;



------------------------------------------------------------------

-- Output

------------------------------------------------------------------

v_actionable_id bigint;

v_step_1_id bigint;

v_step_2_id bigint;



------------------------------------------------------------------

-- Usage Creation Result

------------------------------------------------------------------

v_usage_result boolean;



BEGIN



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_request_id IS NULL THEN

    RAISE EXCEPTION '[STEP_1_COMPLETE_WO][VALIDATION][ERROR] request_id is mandatory';

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION '[STEP_1_COMPLETE_WO][VALIDATION][ERROR] json is mandatory';

END IF;



------------------------------------------------------------------

-- Metadata Validation

------------------------------------------------------------------

------------------------------------------------------------------

-- Metadata Validation

------------------------------------------------------------------

IF p_json -> 'metadata' IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_WO][VALIDATION][ERROR] metadata is mandatory';

END IF;



------------------------------------------------------------------

-- draftedData must be empty

------------------------------------------------------------------

IF COALESCE(

       p_json -> 'draftedData',

       '{}'::jsonb

   ) <> '{}'::jsonb

THEN

    RAISE EXCEPTION

        '[STEP_1_COMPLETE_WO][VALIDATION][ERROR] draftedData must be null or {}';

END IF;



------------------------------------------------------------------

-- At least one order is required

------------------------------------------------------------------

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

        '[STEP_1_COMPLETE_WO][VALIDATION][ERROR] At least one Microservice or Hours entry is required';

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

    RAISE EXCEPTION '[STEP_1_COMPLETE_WO][SESSION][ERROR] Unable to resolve session user';

END IF;



------------------------------------------------------------------

-- Validate Request

------------------------------------------------------------------

SELECT

    r.module,

    r.ref_requests_in_record_id_immediate_parent

INTO

    v_module,

    v_immediate_parent_request_id

FROM public.requests r

WHERE r.in_record_id = p_request_id;



IF v_module IS NULL THEN

    RAISE EXCEPTION '[STEP_1_COMPLETE_WO][REQUEST_VALIDATE][ERROR] Invalid request id %', p_request_id;

END IF;



------------------------------------------------------------------

-- Only Roles Module

------------------------------------------------------------------

IF initcap(lower(trim(v_module))) <> 'Roles' THEN

    RAISE EXCEPTION '[STEP_1_COMPLETE_WO][REQUEST_VALIDATE][ERROR] Request % does not belong to Roles module', p_request_id;

END IF;



------------------------------------------------------------------

-- Immediate Parent Mandatory

------------------------------------------------------------------

IF v_immediate_parent_request_id IS NULL THEN

    RAISE EXCEPTION '[STEP_1_COMPLETE_WO][REQUEST_VALIDATE][ERROR] Immediate parent request not found for request %', p_request_id;

END IF;



------------------------------------------------------------------

-- Create Actionable

------------------------------------------------------------------

INSERT INTO public.actionables (

    actionable_name,

    actionable_category,

    request_subject,

    

   

    created_by,

    action_metadata

)

VALUES (

    'Add Orders',

    'Orders',

    p_request_id,

    

    

    v_created_by,

    p_json

)

RETURNING in_record_id INTO v_actionable_id;



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

RETURNING in_record_id INTO v_step_1_id;



------------------------------------------------------------------

-- Move Step 1 -> Open

------------------------------------------------------------------

UPDATE public.actionables_steps

SET status = 'Open'

WHERE in_record_id = v_step_1_id;



------------------------------------------------------------------

-- Create Step 2 (Immediate Parent)

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

RETURNING in_record_id INTO v_step_2_id;



------------------------------------------------------------------

-- Complete Step 1

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    status = 'Complete',

    ref_users_in_record_id_completed_by = v_created_by

WHERE in_record_id = v_step_1_id;



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

RETURN (

    v_actionable_id,

    v_step_1_id,

    v_step_2_id,

    p_request_id,

    'STEP_1_COMPLETE'

)::public.orders_add_microservice_quantity_response;



END;

$function$