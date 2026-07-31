CREATE OR REPLACE FUNCTION public.app_orders_add_microservice_quantity_step_3_complete_v_0_0_1(p_actionable_step_id bigint, p_request_id bigint, p_response text, p_json jsonb)
 RETURNS TABLE(actionable_id bigint, step_3_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Logging & Session

------------------------------------------------------------------

v_run_id text;

v_txid bigint;

v_user_uuid uuid;

v_created_by bigint;



------------------------------------------------------------------

-- Step 3

------------------------------------------------------------------

v_actionable_id bigint;

v_step_status text;

v_step_no integer;



------------------------------------------------------------------

-- Request

------------------------------------------------------------------

v_request_subject bigint;



------------------------------------------------------------------

-- Inputs

------------------------------------------------------------------

v_reason text;



BEGIN



------------------------------------------------------------------

-- Generate run_id and txid for logging

------------------------------------------------------------------

v_run_id := substring(md5(random()::text), 1, 8);

v_txid := txid_current();



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_actionable_step_id IS NULL THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'actionable_step_id is mandatory', now();

END IF;



IF p_request_id IS NULL THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF p_response IS NULL THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'response is mandatory', now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'json is mandatory', now();

END IF;



------------------------------------------------------------------

-- Normalize response

------------------------------------------------------------------

p_response := upper(trim(p_response));



IF p_response NOT IN ('APPROVE', 'REJECT') THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'response must be APPROVE or REJECT', now();

END IF;



------------------------------------------------------------------

-- JSON Validation

-- metadata must be present

-- draftedData must be null or {}

------------------------------------------------------------------

IF p_json -> 'metadata' IS NULL THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'metadata is mandatory in JSON', now();

END IF;



IF p_json -> 'draftedData' IS NOT NULL AND p_json -> 'draftedData' != '{}'::jsonb THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'draftedData must be null or {} for completed step', now();

END IF;



------------------------------------------------------------------

-- Extract reason from metadata (optional)

------------------------------------------------------------------

v_reason := trim(p_json -> 'metadata' ->> 'reason');



------------------------------------------------------------------

-- Validate reason for REJECT

------------------------------------------------------------------

IF p_response = 'REJECT' AND COALESCE(v_reason, '') = '' THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'reason is mandatory for REJECT', now();

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

    RAISE EXCEPTION '[STEP_3_COMPLETE][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Unable to resolve session user', now();

END IF;



------------------------------------------------------------------

-- Resolve Step 3

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

    ON a.in_record_id = ast.ref_actionables_in_record_id

WHERE ast.in_record_id = p_actionable_step_id;



IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][STEP_RESOLVE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Invalid actionable step id: ' || p_actionable_step_id, now();

END IF;



------------------------------------------------------------------

-- Validate Step

------------------------------------------------------------------

IF v_step_no <> 3 THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Only Step 3 can be completed through this API', now();

END IF;



IF v_step_status NOT IN ('Open') THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step 3 must be Open, Current status = ' || v_step_status, now();

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION '[STEP_3_COMPLETE][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step does not belong to request ' || p_request_id, now();

END IF;



------------------------------------------------------------------

-- Complete Step 3

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    status = 'Complete',

    delivery_decision = initcap(lower(p_response)),

    ref_users_in_record_id_completed_by = v_created_by,

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

    CASE

        WHEN p_response = 'APPROVE'

            THEN 'STEP_3_COMPLETED_APPROVED'

        ELSE

            'STEP_3_COMPLETED_REJECTED'

    END;



END;

$function$