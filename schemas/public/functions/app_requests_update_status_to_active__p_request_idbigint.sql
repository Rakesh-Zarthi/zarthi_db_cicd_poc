CREATE OR REPLACE FUNCTION public.app_requests_update_status_to_active(p_request_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    ------------------------------------------------------------------

    -- SESSION / ACTOR CONTEXT

    ------------------------------------------------------------------

    v_user_uuid   uuid;

    v_actor_id    bigint;



    ------------------------------------------------------------------

    -- REQUEST CONTEXT

    ------------------------------------------------------------------

    v_module         text;

    v_current_status text;

    v_owner_id       bigint;



    ------------------------------------------------------------------

    -- ACTIONABLE

    ------------------------------------------------------------------

    v_actionable_id bigint;

    v_due_date      timestamptz := now() + interval '30 days';



    ------------------------------------------------------------------

    -- RUNTIME

    ------------------------------------------------------------------

    v_rows_updated  integer;

BEGIN

    ------------------------------------------------------------------

    -- 0) Resolve Actor from app.CURRENT_USER_ID

    ------------------------------------------------------------------

    BEGIN

        v_user_uuid := current_setting('app.CURRENT_USER_ID', true)::uuid;

    EXCEPTION WHEN others THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][DENIED] request_id=% | reason=INVALID_OR_MISSING_app.CURRENT_USER_ID',

            p_request_id;

    END;



    IF v_user_uuid IS NULL THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][DENIED] request_id=% | reason=app.CURRENT_USER_ID_NOT_SET',

            p_request_id;

    END IF;



    SELECT u.in_record_id

    INTO v_actor_id

    FROM public.users u

    WHERE u.user_id = v_user_uuid;



    IF v_actor_id IS NULL THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][DENIED] request_id=% | reason=USER_NOT_FOUND_FOR_UUID=%',

            p_request_id, v_user_uuid;

    END IF;



    ------------------------------------------------------------------

    -- 1) Fetch request context (LOCK ROW)

    ------------------------------------------------------------------

    SELECT r.module, r.status, r.owner

    INTO v_module, v_current_status, v_owner_id

    FROM public.requests r

    WHERE r.in_record_id = p_request_id

    FOR UPDATE;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][FAILED] request_id=% | reason=REQUEST_NOT_FOUND',

            p_request_id;

    END IF;



    ------------------------------------------------------------------

    -- 2) Only Problem module allowed

    ------------------------------------------------------------------

    IF v_module IS DISTINCT FROM 'Problem' THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][DENIED] request_id=% | module="%" | reason=ONLY_PROBLEM_ALLOWED',

            p_request_id, v_module;

    END IF;



    ------------------------------------------------------------------

    -- 3) Only owner can restart

    ------------------------------------------------------------------

    IF v_owner_id IS NULL THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][FAILED] request_id=% | reason=PROBLEM_OWNER_REQUIRED',

            p_request_id;

    END IF;



    /*IF v_actor_id IS DISTINCT FROM v_owner_id THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][DENIED] request_id=% | reason=ONLY_OWNER_CAN_RESTART | actor_id=% | owner_id=% | actor_uuid=%',

            p_request_id, v_actor_id, v_owner_id, v_user_uuid;

    END IF;*/



    ------------------------------------------------------------------

    -- 4) Must be Pause

    -- Re-Start allowed on Problem/Pause :contentReference[oaicite:1]{index=1}

    ------------------------------------------------------------------

    IF v_current_status IS DISTINCT FROM 'Pause' THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][FAILED] request_id=% | status="%" | expected="Pause" | reason=ONLY_PAUSE_TO_OPEN_ALLOWED',

            p_request_id, v_current_status;

    END IF;



    RAISE NOTICE

        '[PROBLEM_RESTART][START] request_id=% | status=Pause | actor_id=% | owner_id=%',

        p_request_id, v_actor_id, v_owner_id;



    ------------------------------------------------------------------

    -- 5) Create actionable "Re-Start" while still Pause

    -- due_date mandatory (trigger enforced)

    ------------------------------------------------------------------

    INSERT INTO public.actionables (

        in_ref_added_user_uuid,

        in_ref_modified_user_uuid,

        actionable_creation_time,

        created_by,

        actionable_owner,

        request_subject,

        actionable_category,

        actionable_name,

        actionable_status,

        actionable_description,

        due_date,

        completed_by,

        actionable_completion_time

    )

    VALUES (

        v_user_uuid,

        v_user_uuid,

        now(),

        v_actor_id,

        v_owner_id,

        p_request_id,

        'Status',

        'Re-Start',

        'Complete',

        'Restart the Problem request',

        v_due_date,

        v_actor_id,

        now()

    )

    RETURNING in_record_id

    INTO v_actionable_id;



    RAISE NOTICE

        '[PROBLEM_RESTART][ACTIONABLE] actionable_id=% | due_date=% | status=Complete',

        v_actionable_id, v_due_date;



    ------------------------------------------------------------------

    -- 6) Update request Pause -> Open

    ------------------------------------------------------------------

    UPDATE public.requests

    SET

        status = 'Open',

        in_modified_time = CURRENT_TIMESTAMP

    WHERE in_record_id = p_request_id

      AND status       = 'Pause';



    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;



    IF v_rows_updated = 0 THEN

        RAISE EXCEPTION

            '[PROBLEM_RESTART][FAILED] request_id=% | action=NO_ROWS_UPDATED',

            p_request_id;

    END IF;



    RAISE NOTICE

        '[PROBLEM_RESTART][SUCCESS] request_id=% | new_status=Open | actionable_id=%',

        p_request_id, v_actionable_id;



END;

$function$