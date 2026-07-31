CREATE OR REPLACE FUNCTION public.app_requests_problem_pause(p_request_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_module          TEXT;

    v_current_status  TEXT;

    v_owner_id        BIGINT;

    v_actionable_id   BIGINT;



    v_status_from     TEXT := 'Open';

    v_status_to       TEXT := 'Pause';



    v_rows_updated    INTEGER;

BEGIN

    ------------------------------------------------------------------

    -- 1. LOCK + FETCH REQUEST CONTEXT

    ------------------------------------------------------------------

    SELECT module, status, owner

    INTO v_module, v_current_status, v_owner_id

    FROM public.requests

    WHERE in_record_id = p_request_id

    FOR UPDATE;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            '[PROBLEM_PAUSE][FAILED] request_id=% | reason=REQUEST_NOT_FOUND',

            p_request_id;

    END IF;



    ------------------------------------------------------------------

    -- 2. VALIDATE MODULE + STATUS

    ------------------------------------------------------------------

    IF v_module <> 'Problem' THEN

        RAISE EXCEPTION

            '[PROBLEM_PAUSE][FAILED] request_id=% | module="%" | allowed_module="Problem"',

            p_request_id, v_module;

    END IF;



    IF v_current_status <> v_status_from THEN

        RAISE EXCEPTION

            '[PROBLEM_PAUSE][FAILED] request_id=% | status="%" | expected_status="%"',

            p_request_id, v_current_status, v_status_from;

    END IF;



    ------------------------------------------------------------------

    -- 3. CREATE PAUSE ACTIONABLE (NO STEP)

    ------------------------------------------------------------------

   INSERT INTO public.actionables (

    

   

    actionable_name,

    actionable_category,

    actionable_status,

    request_subject

)

VALUES (

   

    'Pause',

    'Status',

    'Open',

    p_request_id

)

RETURNING in_record_id

INTO v_actionable_id;



    ------------------------------------------------------------------

    -- 4. UPDATE REQUEST STATUS

    ------------------------------------------------------------------

    UPDATE public.requests

    SET status = v_status_to,

        in_modified_time = clock_timestamp()

    WHERE in_record_id = p_request_id

      AND status = v_status_from;



    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;



    IF v_rows_updated = 0 THEN

        RAISE EXCEPTION

            '[PROBLEM_PAUSE][FAILED] request_id=% | action=NO_ROWS_UPDATED',

            p_request_id;

    END IF;



    ------------------------------------------------------------------

    -- 5. BULK COMPLETE (Config = true)

    ------------------------------------------------------------------

    UPDATE public.actionables

    SET actionable_status = 'Complete'

    WHERE in_record_id = v_actionable_id;



    RAISE NOTICE

        '[PROBLEM_PAUSE][SUCCESS] request_id=% | actionable_id=%',

        p_request_id, v_actionable_id;



END;

$function$