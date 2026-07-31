CREATE OR REPLACE FUNCTION public.app_orders_add_microservice_quantity_step_1_planned_wo_actionab(p_request_id bigint, p_json jsonb, p_description text)
 RETURNS TABLE(actionable_id bigint, step_1_id bigint, request_id bigint, workflow_state text)
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

-- Request

------------------------------------------------------------------

v_module text;



------------------------------------------------------------------

-- Metadata

------------------------------------------------------------------

v_step_metadata jsonb;



------------------------------------------------------------------

-- Output

------------------------------------------------------------------

v_actionable_id bigint;

v_step_1_id bigint;



BEGIN



------------------------------------------------------------------

-- Generate run_id and txid for logging

------------------------------------------------------------------

v_run_id := substring(md5(random()::text), 1, 8);

v_txid := txid_current();



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_request_id IS NULL THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF COALESCE(trim(p_description), '') = '' THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'description is mandatory', now();

END IF;





IF p_json IS NULL THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'json is mandatory', now();

END IF;



------------------------------------------------------------------

-- JSON Validation

-- metadata must be present

-- draftedData must be null or {}

------------------------------------------------------------------

IF p_json -> 'metadata' IS NULL THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'metadata is mandatory in JSON', now();

END IF;



IF p_json -> 'draftedData' IS NOT NULL AND p_json -> 'draftedData' != '{}'::jsonb THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'draftedData must be null or {} for planned step', now();

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

    RAISE EXCEPTION '[STEP_1_PLANNED_WO][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Unable to resolve session user', now();

END IF;



------------------------------------------------------------------

-- Validate Request

------------------------------------------------------------------

SELECT r.module

INTO v_module

FROM public.requests r

WHERE r.in_record_id = p_request_id;



IF v_module IS NULL THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_WO][REQUEST_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Invalid request id ' || p_request_id, now();

END IF;



------------------------------------------------------------------

-- Roles Only

------------------------------------------------------------------

IF initcap(lower(trim(v_module))) <> 'Roles' THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_WO][REQUEST_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Request ' || p_request_id || ' does not belong to Roles module', now();

END IF;



------------------------------------------------------------------

-- Build Metadata

------------------------------------------------------------------

v_step_metadata := p_json;



------------------------------------------------------------------

-- Create Actionable

------------------------------------------------------------------

INSERT INTO public.actionables (

    actionable_name,

    actionable_category,

    request_subject,

    ref_requests_in_record_id,

    actionable_description,

    created_by

)

VALUES (

    'Add Microservice Quantity',

    'Orders',

    p_request_id,

    p_request_id,

	p_description,

    v_created_by

)

RETURNING in_record_id INTO v_actionable_id;



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

RETURNING in_record_id INTO v_step_1_id;



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    v_step_1_id,

    p_request_id,

    'STEP_1_PLANNED_SAVED'::text;



END;

$function$