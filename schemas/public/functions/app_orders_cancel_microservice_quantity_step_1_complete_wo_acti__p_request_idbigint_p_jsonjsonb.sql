CREATE OR REPLACE FUNCTION public.app_orders_cancel_microservice_quantity_step_1_complete_wo_acti(p_request_id bigint, p_json jsonb)
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

-- Actionable

------------------------------------------------------------------

v_actionable_id bigint;



------------------------------------------------------------------

-- Step 1

------------------------------------------------------------------

v_step_1_id bigint;



------------------------------------------------------------------

-- JSON Fields

------------------------------------------------------------------

v_quantity numeric;

v_ms_id bigint;

v_cancellation_reason text;



------------------------------------------------------------------

-- Usage Validation

------------------------------------------------------------------

v_in_progress_count bigint;





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

    RAISE EXCEPTION '[CANCEL_STEP_1_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'json is mandatory', now();

END IF;



------------------------------------------------------------------

-- Extract JSON Fields

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

-- Validate JSON Fields

------------------------------------------------------------------

IF v_quantity IS NULL OR v_quantity <= 0 OR v_quantity <> FLOOR(v_quantity) THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'quantity must be a positive whole number', now();

END IF;



IF v_ms_id IS NULL THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'msId is mandatory', now();

END IF;



IF v_cancellation_reason IS NULL OR v_cancellation_reason = '' THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'cancellationReason is mandatory', now();

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

    RAISE EXCEPTION '[CANCEL_STEP_1_WO][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Unable to resolve session user', now();

END IF;



------------------------------------------------------------------

-- Validate Request Module

------------------------------------------------------------------

IF NOT EXISTS (

    SELECT 1 FROM public.requests r

    WHERE r.in_record_id = p_request_id AND r.module = 'Roles'

) THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_WO][REQUEST_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Invalid request or not in Roles module', now();

END IF;



------------------------------------------------------------------

-- Validate Usage Exists

------------------------------------------------------------------

SELECT COUNT(*)

INTO v_in_progress_count

FROM public.usage u

WHERE u.ref_requests_in_record_id = p_request_id

  AND u.ref_services_sku_in_record_id = v_ms_id

  AND u.status = 'Delivery In Progress';



IF v_in_progress_count < v_quantity THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_WO][USAGE_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Not enough in-progress records to cancel. Available: ' || v_in_progress_count, now();

END IF;



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

RETURNING in_record_id INTO v_actionable_id;



------------------------------------------------------------------

-- Create Step 1 (Planned)

------------------------------------------------------------------

INSERT INTO public.actionables_steps (

    ref_actionables_in_record_id,

    ref_requests_in_record_id_assigned_to,

    step_no,

    status,

    step_metadata,

    ref_users_in_record_id_completed_by

)

VALUES (

    v_actionable_id,

    p_request_id,

    1,

    'Planned',

	p_json,

    v_created_by

)

RETURNING in_record_id INTO v_step_1_id;







------------------------------------------------------------------

-- Update Step 1 to Complete

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    status = 'Complete',

    ref_users_in_record_id_completed_by = v_created_by,

    step_metadata = p_json

WHERE in_record_id = v_step_1_id;



------------------------------------------------------------------

-- Cancel Latest N Records

------------------------------------------------------------------

WITH latest_usage AS (

    SELECT in_record_id

    FROM public.usage

    WHERE ref_requests_in_record_id = p_request_id

      AND ref_services_sku_in_record_id = v_ms_id

      AND status = 'Delivery In Progress'

    ORDER BY in_record_id DESC

    LIMIT v_quantity::integer

)

UPDATE public.usage

SET

    status = 'Cancelled'

WHERE in_record_id IN (SELECT in_record_id FROM latest_usage);



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    v_step_1_id,

    p_request_id,

    'STEP_1_CANCELLED'::text;



END;

$function$