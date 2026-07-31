CREATE OR REPLACE FUNCTION public.app_orders_cancel_microservice_quantity_step_1_complete_via_act(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb)
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

-- Step 1

------------------------------------------------------------------

v_actionable_id bigint;

v_step_status text;

v_step_no integer;



------------------------------------------------------------------

-- Request

------------------------------------------------------------------

v_request_subject bigint;



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

IF p_actionable_step_id IS NULL THEN

    RAISE EXCEPTION '[CANCEL_STEP_1][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'actionable_step_id is mandatory', now();

END IF;



IF p_request_id IS NULL THEN

    RAISE EXCEPTION '[CANCEL_STEP_1][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION '[CANCEL_STEP_1][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

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

    RAISE EXCEPTION '[CANCEL_STEP_1][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'quantity must be a positive whole number', now();

END IF;



IF v_ms_id IS NULL THEN

    RAISE EXCEPTION '[CANCEL_STEP_1][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'msId is mandatory', now();

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

    RAISE EXCEPTION '[CANCEL_STEP_1][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Unable to resolve session user', now();

END IF;



------------------------------------------------------------------

-- Resolve Step 1

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

    RAISE EXCEPTION '[CANCEL_STEP_1][STEP_RESOLVE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Invalid actionable step id: ' || p_actionable_step_id, now();

END IF;



------------------------------------------------------------------

-- Validate Step

------------------------------------------------------------------

IF v_step_no <> 1 THEN

    RAISE EXCEPTION '[CANCEL_STEP_1][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Only Step 1 can be completed through this API', now();

END IF;



IF v_step_status NOT IN ('Planned', 'Draft') THEN

    RAISE EXCEPTION '[CANCEL_STEP_1][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step 1 must be Planned or Draft. Current status = ' || v_step_status, now();

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION '[CANCEL_STEP_1][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step does not belong to request ' || p_request_id, now();

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

    RAISE EXCEPTION '[CANCEL_STEP_1][USAGE_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Not enough In-progress records to cancel. Available: ' || v_in_progress_count, now();

END IF;







------------------------------------------------------------------

-- Complete Step 1

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    status = 'Complete',

    ref_users_in_record_id_completed_by = v_created_by,

    step_metadata = p_json

WHERE in_record_id = p_actionable_step_id;





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

    p_actionable_step_id,

    p_request_id,

    'STEP_1_CANCELLED'::text;



END;

$function$