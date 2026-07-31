CREATE OR REPLACE FUNCTION public.app_orders_cancel_micros_quantity_step_1_planned_complete_wo_ac(p_request_id bigint, p_json jsonb)
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

-- JSON Fields

------------------------------------------------------------------

v_quantity numeric;

v_ms_id bigint;

v_cancellation_reason text;



------------------------------------------------------------------

-- Metadata

------------------------------------------------------------------

v_step_1_metadata jsonb;



------------------------------------------------------------------

-- Output

------------------------------------------------------------------

v_actionable_id bigint;

v_step_1_id bigint;



BEGIN



------------------------------------------------------------------

-- Generate run_id and txid

------------------------------------------------------------------

v_run_id := substring(md5(random()::text), 1, 8);

v_txid := txid_current();



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_request_id IS NULL THEN

    RAISE EXCEPTION

        '[CANCEL_STEP_1_COMPLETE_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id,

        v_txid,

        'request_id is mandatory',

        now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION

        '[CANCEL_STEP_1_COMPLETE_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id,

        v_txid,

        'json is mandatory',

        now();

END IF;



------------------------------------------------------------------

-- JSON Validation

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

-- Extract Metadata Fields

------------------------------------------------------------------

v_quantity :=

    (p_json -> 'metadata' ->> 'quantity')::numeric;



v_ms_id :=

    (p_json -> 'metadata' ->> 'msId')::bigint;



v_cancellation_reason :=

    trim(

        p_json -> 'metadata' ->> 'cancellationReason'

    );



------------------------------------------------------------------

-- Validate Business Fields

------------------------------------------------------------------

IF v_quantity IS NULL

   OR v_quantity <= 0

   OR v_quantity <> FLOOR(v_quantity)

THEN

    RAISE EXCEPTION

        '[CANCEL_STEP_1_COMPLETE_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id,

        v_txid,

        'quantity must be a positive whole number',

        now();

END IF;



IF v_ms_id IS NULL THEN

    RAISE EXCEPTION

        '[CANCEL_STEP_1_COMPLETE_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id,

        v_txid,

        'msId is mandatory',

        now();

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

        '[CANCEL_STEP_1_COMPLETE_WO][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id,

        v_txid,

        'Unable to resolve session user',

        now();

END IF;



------------------------------------------------------------------

-- Validate Request

------------------------------------------------------------------

SELECT r.module

INTO v_module

FROM public.requests r

WHERE r.in_record_id = p_request_id;



IF v_module IS NULL THEN

    RAISE EXCEPTION

        '[CANCEL_STEP_1_COMPLETE_WO][REQUEST][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id,

        v_txid,

        'Invalid request id',

        now();

END IF;



IF initcap(lower(trim(v_module))) <> 'Roles' THEN

    RAISE EXCEPTION

        '[CANCEL_STEP_1_COMPLETE_WO][REQUEST][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id,

        v_txid,

        'Request does not belong to Roles module',

        now();

END IF;



------------------------------------------------------------------

-- Step 1 Metadata

------------------------------------------------------------------

v_step_1_metadata := p_json;



------------------------------------------------------------------

-- Create Actionable

------------------------------------------------------------------

INSERT INTO public.actionables (

    actionable_name,

    actionable_category,

    request_subject,

    ref_requests_in_record_id,

    created_by,

    actionable_creation_time

)

VALUES (

    'Cancel Microservice Quantity',

    'Orders',

    p_request_id,

    p_request_id,

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

    v_step_1_metadata

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

    'STEP_1_COMPLETE'::text;



END;

$function$