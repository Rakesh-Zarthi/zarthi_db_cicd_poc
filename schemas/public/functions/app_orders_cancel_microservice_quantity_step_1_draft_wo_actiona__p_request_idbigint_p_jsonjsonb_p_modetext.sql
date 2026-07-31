CREATE OR REPLACE FUNCTION public.app_orders_cancel_microservice_quantity_step_1_draft_wo_actiona(p_request_id bigint, p_json jsonb, p_mode text DEFAULT 'DRAFT'::text)
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

-- Mode

------------------------------------------------------------------

v_mode text;



------------------------------------------------------------------

-- JSON Fields

------------------------------------------------------------------

v_quantity numeric;

v_ms_id bigint;

v_cancellation_reason text;



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

    RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'json is mandatory', now();

END IF;



------------------------------------------------------------------

-- Normalize Mode

------------------------------------------------------------------

v_mode := upper(trim(p_mode));



IF v_mode NOT IN (

    'DRAFT',

    'PLANNED_DRAFT'

)

THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'mode must be DRAFT or PLANNED_DRAFT', now();

END IF;



------------------------------------------------------------------

-- JSON Validation

------------------------------------------------------------------

IF v_mode = 'DRAFT' THEN



    IF p_json -> 'draftedData' IS NULL THEN

        RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

            v_run_id, v_txid, 'draftedData is mandatory in JSON', now();

    END IF;



    IF COALESCE(

        p_json -> 'metadata',

        '{}'::jsonb

    ) <> '{}'::jsonb

    THEN

        RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

            v_run_id, v_txid, 'metadata must be null or {} for draft step', now();

    END IF;



ELSIF v_mode = 'PLANNED_DRAFT' THEN



    IF p_json -> 'draftedData' IS NULL

       OR p_json -> 'draftedData' = '{}'::jsonb

    THEN

        RAISE EXCEPTION

            '[CANCEL_STEP_1_DRAFT_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

            v_run_id,

            v_txid,

            'draftedData is mandatory in JSON',

            now();

    END IF;



    IF p_json -> 'metadata' IS NOT NULL

       AND p_json -> 'metadata' <> '{}'::jsonb

    THEN

        RAISE EXCEPTION

            '[CANCEL_STEP_1_DRAFT_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

            v_run_id,

            v_txid,

            'metadata must be null or {} for planned draft step',

            now();

    END IF;



END IF;





------------------------------------------------------------------

-- Extract JSON Fields

------------------------------------------------------------------

v_quantity :=

    (p_json -> 'draftedData' ->> 'quantity')::numeric;



v_ms_id :=

    (p_json -> 'draftedData' ->> 'msId')::bigint;



v_cancellation_reason :=

    trim(

        p_json -> 'draftedData' ->> 'cancellationReason'

    );



------------------------------------------------------------------

-- Optional Validation

------------------------------------------------------------------

IF v_quantity IS NOT NULL

   AND (

        v_quantity <= 0

        OR v_quantity <> FLOOR(v_quantity)

   )

THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'quantity must be a positive whole number', now();

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

    RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Unable to resolve session user', now();

END IF;



------------------------------------------------------------------

-- Validate Request Module

------------------------------------------------------------------

SELECT r.module

INTO v_module

FROM public.requests r

WHERE r.in_record_id = p_request_id;



IF v_module IS NULL THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][REQUEST_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Invalid request id ' || p_request_id, now();

END IF;



IF initcap(lower(trim(v_module))) <> 'Roles' THEN

    RAISE EXCEPTION '[CANCEL_STEP_1_DRAFT_WO][REQUEST_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Request ' || p_request_id || ' does not belong to Roles module', now();

END IF;



------------------------------------------------------------------

-- Build Metadata

------------------------------------------------------------------

v_step_metadata :=

    jsonb_build_object(

        'metadata', '{}'::jsonb,

        'draftedData', p_json -> 'draftedData'

    );



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

    v_step_metadata

)

RETURNING in_record_id

INTO v_step_1_id;



------------------------------------------------------------------

-- Move to Draft if Required

------------------------------------------------------------------

IF v_mode = 'DRAFT' THEN



    UPDATE public.actionables_steps

    SET status = 'Draft'

    WHERE in_record_id = v_step_1_id;



END IF;



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    v_step_1_id,

    p_request_id,

    CASE

        WHEN v_mode = 'DRAFT'

            THEN 'STEP_1_DRAFT_SAVED'

        ELSE

            'STEP_1_PLANNED_DRAFT_SAVED'

    END;



END;

$function$