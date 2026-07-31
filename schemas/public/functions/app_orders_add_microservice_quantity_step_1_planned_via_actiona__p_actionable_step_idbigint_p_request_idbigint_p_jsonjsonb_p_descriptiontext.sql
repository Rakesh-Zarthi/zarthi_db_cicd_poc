CREATE OR REPLACE FUNCTION public.app_orders_add_microservice_quantity_step_1_planned_via_actiona(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb, p_description text DEFAULT NULL::text)
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

-- Structured Fields

------------------------------------------------------------------

v_quantity numeric;

v_ms_id bigint;





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

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'actionable_step_id is mandatory', now();

END IF;



IF p_request_id IS NULL THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'json is mandatory', now();

END IF;



------------------------------------------------------------------

-- JSON Validation

------------------------------------------------------------------

IF p_json -> 'metadata' IS NULL THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'metadata is mandatory in JSON', now();

END IF;



IF p_json -> 'draftedData' IS NOT NULL

   AND p_json -> 'draftedData' <> '{}'::jsonb

THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'draftedData must be null or {} for planned step', now();

END IF;



------------------------------------------------------------------

-- Extract structured fields

------------------------------------------------------------------

v_quantity :=

    NULLIF(

        p_json -> 'metadata' ->> 'quantity',

        ''

    )::numeric;



v_ms_id :=

    NULLIF(

        p_json -> 'metadata' ->> 'msId',

        ''

    )::bigint;



------------------------------------------------------------------

-- Validate quantity if present

------------------------------------------------------------------

IF v_quantity IS NOT NULL THEN



    IF v_quantity <= 0

       OR v_quantity <> floor(v_quantity)

    THEN

        RAISE EXCEPTION '[STEP_1_PLANNED_VIA][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

            v_run_id, v_txid, 'quantity must be a positive whole number', now();

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

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

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

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][STEP_RESOLVE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Invalid actionable step id: ' || p_actionable_step_id, now();

END IF;



------------------------------------------------------------------

-- Validate Step

------------------------------------------------------------------

IF v_step_no <> 1 THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Only Step 1 can be planned through this API', now();

END IF;



IF v_step_status <> 'Planned' THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step 1 must be Planned. Current status = ' || v_step_status, now();

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION '[STEP_1_PLANNED_VIA][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step does not belong to request ' || p_request_id, now();

END IF;





------------------------------------------------------------------

-- Update Step Metadata

------------------------------------------------------------------

UPDATE public.actionables_steps

SET step_metadata = p_json

WHERE in_record_id = p_actionable_step_id;



------------------------------------------------------------------

-- Update Description If Provided

------------------------------------------------------------------

IF COALESCE(trim(p_description), '') <> '' THEN



    UPDATE public.actionables

    SET actionable_description = p_description

    WHERE in_record_id = v_actionable_id;



END IF;



------------------------------------------------------------------

-- Ensure Status is Planned

------------------------------------------------------------------

UPDATE public.actionables_steps

SET status = 'Planned'

WHERE in_record_id = p_actionable_step_id;



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    p_actionable_step_id,

    p_request_id,

    'STEP_1_PLANNED_SAVED'::text;



END;

$function$