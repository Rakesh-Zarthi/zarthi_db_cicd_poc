CREATE OR REPLACE FUNCTION public.app_roles_request_work(p_owner_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(request_id bigint, module text, old_status text, new_status text, in_added_time timestamp with time zone, message text)
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_owner_id      bigint;

    v_user_uuid     uuid;

    v_actionable_id bigint;



    v_old_status    text := 'Backlog';

    v_new_status    text := 'In Progress';



    -- Logging helpers

    v_run_id text := substr(md5(random()::text || clock_timestamp()::text), 1, 8);

    v_txid   bigint := txid_current();

BEGIN

    ------------------------------------------------------------------

    -- Resolve Owner Id

    ------------------------------------------------------------------

    IF p_owner_id IS NOT NULL THEN

        v_owner_id := p_owner_id;



        RAISE NOTICE

            '[REQUEST_WORK][OWNER_RESOLVED][INFO] run_id=% txid=% owner_id=% source=p_owner_id ts=%',

            v_run_id, v_txid, v_owner_id, clock_timestamp();

    ELSE

        BEGIN

            v_user_uuid := current_setting('app.CURRENT_USER_ID', true)::uuid;

        EXCEPTION WHEN others THEN

            RAISE EXCEPTION

                '[REQUEST_WORK][OWNER_RESOLVE][ERROR] run_id=% txid=% reason=INVALID_OR_MISSING_CURRENT_USER_ID expected=UUID ts=%',

                v_run_id, v_txid, clock_timestamp();

        END;



        IF v_user_uuid IS NULL THEN

            RAISE EXCEPTION

                '[REQUEST_WORK][OWNER_RESOLVE][ERROR] run_id=% txid=% reason=CURRENT_USER_ID_NOT_SET ts=%',

                v_run_id, v_txid, clock_timestamp();

        END IF;



        SELECT u.in_record_id

        INTO v_owner_id

        FROM public.users u

        WHERE u.user_id = v_user_uuid;



        IF v_owner_id IS NULL THEN

            RAISE EXCEPTION

                '[REQUEST_WORK][OWNER_RESOLVE][ERROR] run_id=% txid=% reason=USER_NOT_FOUND current_user_uuid=% ts=%',

                v_run_id, v_txid, v_user_uuid, clock_timestamp();

        END IF;



        RAISE NOTICE

            '[REQUEST_WORK][OWNER_RESOLVED][INFO] run_id=% txid=% owner_id=% source=current_user_uuid=% ts=%',

            v_run_id, v_txid, v_owner_id, v_user_uuid, clock_timestamp();

    END IF;



    ------------------------------------------------------------------

    -- START

    ------------------------------------------------------------------

    RAISE NOTICE

        '[REQUEST_WORK][START][INFO] run_id=% txid=% owner_id=% old_status=% new_status=% ts=%',

        v_run_id, v_txid, v_owner_id, v_old_status, v_new_status, clock_timestamp();



    ------------------------------------------------------------------

    -- FIND OLDEST ELIGIBLE REQUEST (lock row)

    ------------------------------------------------------------------

    RAISE NOTICE

        '[REQUEST_WORK][SEARCH][INFO] run_id=% txid=% owner_id=% modules=Services,Staffing status=% ts=%',

        v_run_id, v_txid, v_owner_id, v_old_status, clock_timestamp();



    SELECT

        r.in_record_id,

        r.module,

        r.status,

        r.in_added_time

    INTO

        request_id,

        module,

        old_status,

        in_added_time

    FROM public.requests r

    WHERE r.owner = v_owner_id

      AND r.module IN ('Services', 'Staffing','Roles')

      AND r.status = v_old_status

    ORDER BY r.in_added_time

    LIMIT 1

    FOR UPDATE SKIP LOCKED;



    ------------------------------------------------------------------

    -- NO REQUEST FOUND

    ------------------------------------------------------------------

    IF request_id IS NULL THEN

        message := format(

            '[REQUEST_WORK][NO_ACTION][WARN] run_id=%s txid=%s owner_id=%s reason=NO_BACKLOG_REQUEST_FOUND ts=%s',

            v_run_id, v_txid, v_owner_id, clock_timestamp()

        );



        RAISE NOTICE '%', message;



        RETURN QUERY

        SELECT

            NULL::bigint,

            NULL::text,

            NULL::text,

            NULL::text,

            NULL::timestamptz,

            message;



        RETURN;

    END IF;



    ------------------------------------------------------------------

    -- REQUEST LOCKED

    ------------------------------------------------------------------

    RAISE NOTICE

        '[REQUEST_WORK][LOCKED][INFO] run_id=% txid=% owner_id=% request_id=% module=% added_at=% ts=%',

        v_run_id, v_txid, v_owner_id, request_id, module, in_added_time, clock_timestamp();



    ------------------------------------------------------------------

    -- CREATE ROLE ACTIONABLE

    ------------------------------------------------------------------

    RAISE NOTICE

        '[REQUEST_WORK][ACTIONABLE_CREATE][INFO] run_id=% txid=% owner_id=% name=% category=% status=% ts=%',

        v_run_id, v_txid, v_owner_id,

        'Request Work', 'User/ Self Service', 'Open', clock_timestamp();



    INSERT INTO public.actionables (

        actionable_creation_time,

        created_by,

        actionable_name,

        actionable_category,

        actionable_status

    )

    VALUES (

        now(),

        v_owner_id,

        'Request Work',

        'User/ Self Service',

        'Open'

    )

    RETURNING in_record_id

    INTO v_actionable_id;



    RAISE NOTICE

        '[REQUEST_WORK][ACTIONABLE_CREATED][OK] run_id=% txid=% actionable_id=% owner_id=% ts=%',

        v_run_id, v_txid, v_actionable_id, v_owner_id, clock_timestamp();



    ------------------------------------------------------------------

    -- UPDATE REQUEST STATUS

    ------------------------------------------------------------------

    UPDATE public.requests

    SET status = v_new_status

    WHERE in_record_id = request_id

      AND status = v_old_status;



    RAISE NOTICE

        '[REQUEST_WORK][STATUS_UPDATED][OK] run_id=% txid=% request_id=% module=% old_status=% new_status=% ts=%',

        v_run_id, v_txid, request_id, module, old_status, v_new_status, clock_timestamp();



    ------------------------------------------------------------------

    -- COMPLETE ACTIONABLE

    ------------------------------------------------------------------

    UPDATE public.actionables

    SET actionable_status = 'Complete',

        completed_by = v_owner_id,

        actionable_completion_time = now()

    WHERE in_record_id = v_actionable_id;



    RAISE NOTICE

        '[REQUEST_WORK][ACTIONABLE_COMPLETED][OK] run_id=% txid=% actionable_id=% completed_by=% ts=%',

        v_run_id, v_txid, v_actionable_id, v_owner_id, clock_timestamp();



    ------------------------------------------------------------------

    -- SUCCESS RESPONSE

    ------------------------------------------------------------------

    message := format(

        '[REQUEST_WORK][SUCCESS][OK] run_id=%s txid=%s owner_id=%s request_id=%s module=%s %sΓåÆ%s ts=%s',

        v_run_id, v_txid, v_owner_id, request_id, module, old_status, v_new_status, clock_timestamp()

    );



    RAISE NOTICE '%', message;



    RETURN QUERY

    SELECT

        request_id,

        module,

        old_status,

        v_new_status,

        in_added_time,

        message;



END;

$function$