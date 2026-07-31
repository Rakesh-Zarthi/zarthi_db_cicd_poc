CREATE OR REPLACE FUNCTION public.app_orders_add_microservice_quantity_step_2_draft_v_0_0_1(p_actionable_step_id bigint, p_request_id bigint, p_response text DEFAULT NULL::text, p_json jsonb DEFAULT NULL::jsonb)
 RETURNS TABLE(actionable_id bigint, step_2_id bigint, request_id bigint, workflow_state text)
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

-- Step 2

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

    RAISE EXCEPTION '[STEP_2_DRAFT][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'actionable_step_id is mandatory', now();

END IF;



IF p_request_id IS NULL THEN

    RAISE EXCEPTION '[STEP_2_DRAFT][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION '[STEP_2_DRAFT][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'json is mandatory', now();

END IF;



------------------------------------------------------------------

-- Normalize response (optional)

------------------------------------------------------------------

IF p_response IS NOT NULL THEN

    p_response := upper(trim(p_response));

    IF p_response NOT IN ('APPROVE', 'REJECT') THEN

        RAISE EXCEPTION '[STEP_2_DRAFT][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

            v_run_id, v_txid, 'response must be APPROVE or REJECT', now();

    END IF;

END IF;



------------------------------------------------------------------

-- JSON Validation

-- draftedData must be present

-- metadata must be null or {}

------------------------------------------------------------------

IF p_json -> 'draftedData' IS NULL THEN

    RAISE EXCEPTION '[STEP_2_DRAFT][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'draftedData is mandatory in JSON', now();

END IF;



IF p_json -> 'metadata' IS NOT NULL AND p_json -> 'metadata' != '{}'::jsonb THEN

    RAISE EXCEPTION '[STEP_2_DRAFT][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'metadata must be null or {} for draft step', now();

END IF;



------------------------------------------------------------------

-- Extract reason from draftedData (optional)

------------------------------------------------------------------

v_reason := trim(p_json -> 'draftedData' ->> 'reason');



------------------------------------------------------------------

-- Resolve Session User

------------------------------------------------------------------

v_user_uuid := current_setting('app.CURRENT_USER_ID', true)::uuid;



SELECT u.in_record_id

INTO v_created_by

FROM public.users u

WHERE u.user_id = v_user_uuid;



IF v_created_by IS NULL THEN

    RAISE EXCEPTION '[STEP_2_DRAFT][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Unable to resolve session user', now();

END IF;



------------------------------------------------------------------

-- Resolve Step 2

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

    RAISE EXCEPTION '[STEP_2_DRAFT][STEP_RESOLVE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Invalid actionable step id: ' || p_actionable_step_id, now();

END IF;



------------------------------------------------------------------

-- Validate Step

------------------------------------------------------------------

IF v_step_no <> 2 THEN

    RAISE EXCEPTION '[STEP_2_DRAFT][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Only Step 2 can be drafted through this', now();

END IF;



IF v_step_status <> 'Open' THEN

    RAISE EXCEPTION '[STEP_2_DRAFT][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step 2 must be Open. Current status = ' || v_step_status, now();

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION '[STEP_2_DRAFT][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step does not belong to request ' || p_request_id, now();

END IF;



------------------------------------------------------------------

-- Update Step Metadata

------------------------------------------------------------------

UPDATE public.actionables_steps

SET step_metadata = jsonb_build_object(

    'metadata', '{}',

    'draftedData', p_json -> 'draftedData'

)

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