CREATE OR REPLACE FUNCTION public.app_add_orders_step_1_planned_wo_actionable(p_request_id bigint, p_json jsonb)
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

        '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'json is mandatory', now();

END IF;



------------------------------------------------------------------

-- JSON Validation

------------------------------------------------------------------

IF p_json -> 'metadata' IS NULL THEN

    RAISE EXCEPTION

        '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'metadata is mandatory', now();

END IF;



IF COALESCE(

       p_json -> 'draftedData',

       '{}'::jsonb

   ) <> '{}'::jsonb

THEN

    RAISE EXCEPTION

        '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid,

        'draftedData must be null or {} for planned step',

        now();

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

        '[STEP_1_PLANNED_WO][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid,

        'At least one Microservice or Hours entry is required',

        now();

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

        '[STEP_1_PLANNED_WO][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid,

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

        '[STEP_1_PLANNED_WO][REQUEST_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid,

        'Invalid request id ' || p_request_id,

        now();

END IF;



------------------------------------------------------------------

-- Roles Only

------------------------------------------------------------------

IF initcap(lower(trim(v_module))) <> 'Roles' THEN

    RAISE EXCEPTION

        '[STEP_1_PLANNED_WO][REQUEST_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid,

        'Request ' || p_request_id || ' does not belong to Roles module',

        now();

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

    action_metadata

)

VALUES (

    'Add Orders',

    'Orders',

    p_request_id,

    p_request_id,

    v_created_by,

    p_json

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

    p_json

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

    'STEP_1_PLANNED_SAVED'::text;



END;

$function$