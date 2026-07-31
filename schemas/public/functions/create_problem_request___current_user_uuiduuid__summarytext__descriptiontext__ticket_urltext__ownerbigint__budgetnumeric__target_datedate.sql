CREATE OR REPLACE FUNCTION public.create_problem_request(_current_user_uuid uuid, _summary text, _description text, _ticket_url text, _owner bigint, _budget numeric, _target_date date)
 RETURNS TABLE(request_id bigint, problem_id bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

DECLARE

    v_request_id bigint;

    v_problem_id bigint;



    -- diagnostics

    v_sqlstate text;

    v_message  text;

    v_detail   text;

    v_hint     text;

    v_context  text;

BEGIN

    -- session context

    PERFORM set_config('app.CURRENT_USER_ID', _current_user_uuid::text, true);



    -----------------------------

    -- Insert into requests

    -----------------------------

    INSERT INTO public.requests (

        in_ref_added_user_uuid,

        request_dependency,

        request_origin,

        summary,

        description,

        ticket_url,

        module,

        owner,

        status

    )

    VALUES (

        _current_user_uuid,

        'Standalone',

        'Internal',

        _summary,

        _description,

        _ticket_url,

        'Problem',

        _owner,

        'Open'

    )

    RETURNING in_record_id INTO v_request_id;



    -----------------------------

    -- Insert into requests_problem

    -----------------------------

    INSERT INTO public.requests_problem (

        budget,

        tagret_completion_date,

        reason_for_hold,

        ref_requests_record_id

    )

    VALUES (

        _budget,

        _target_date,

        NULL,

        v_request_id

    )

    RETURNING in_record_id INTO v_problem_id;



    -----------------------------

    -- return values

    -----------------------------

    request_id := v_request_id;

    problem_id := v_problem_id;

    RETURN NEXT;



EXCEPTION

WHEN OTHERS THEN

    GET STACKED DIAGNOSTICS

        v_sqlstate = RETURNED_SQLSTATE,

        v_message  = MESSAGE_TEXT,

        v_detail   = PG_EXCEPTION_DETAIL,

        v_hint     = PG_EXCEPTION_HINT,

        v_context  = PG_EXCEPTION_CONTEXT;



    -- structured telemetry (great for logs)

    RAISE NOTICE 'ERROR_JSON = %',

        jsonb_build_object(

            'sqlstate', v_sqlstate,

            'message',  v_message,

            'detail',   v_detail,

            'hint',     v_hint,

            'context',  v_context

        );



    RAISE;

END;

$function$