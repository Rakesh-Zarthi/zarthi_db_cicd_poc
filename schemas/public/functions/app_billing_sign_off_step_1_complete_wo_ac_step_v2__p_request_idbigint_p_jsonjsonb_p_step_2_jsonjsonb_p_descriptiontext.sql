CREATE OR REPLACE FUNCTION public.app_billing_sign_off_step_1_complete_wo_ac_step_v2(p_request_id bigint, p_json jsonb, p_step_2_json jsonb, p_description text DEFAULT NULL::text)
 RETURNS TABLE(actionable_id bigint, step_1_id bigint, step_2_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$

DECLARE

    ------------------------------------------------------------------

    -- Session

    ------------------------------------------------------------------

    v_user_uuid UUID;

    v_created_by BIGINT;



    ------------------------------------------------------------------

    -- Request

    ------------------------------------------------------------------

    v_immediate_parent_request_id BIGINT;

    v_professional_id BIGINT; 

v_existing_timesheet_id BIGINT;



    ------------------------------------------------------------------

    -- Metadata

    ------------------------------------------------------------------

    v_sign_off_type TEXT;

    v_name TEXT;

    v_ms_id BIGINT;

    v_task_name TEXT;

    v_quantity NUMERIC;

    v_timesheet JSONB;



    ------------------------------------------------------------------

    -- Output

    ------------------------------------------------------------------

    v_actionable_id BIGINT;

    v_step_1_id BIGINT;

    v_step_2_id BIGINT;



    ------------------------------------------------------------------

    -- Timesheet Loop Variables

    ------------------------------------------------------------------

    ts JSONB;

    v_from_date TEXT;

    v_from_time TEXT;

    v_to_date TEXT;

    v_to_time TEXT;

    v_desc TEXT;

    v_from_dt DATE_TIME;

    v_to_dt DATE_TIME;

    v_timesheet_id BIGINT;

    v_calculated_hours NUMERIC;

    v_total_calculated_hours NUMERIC := 0;

BEGIN



    ------------------------------------------------------------------

    -- Mandatory Validation

    ------------------------------------------------------------------

    IF p_request_id IS NULL THEN

        RAISE EXCEPTION 'request_id is mandatory';

    END IF;



    IF p_json IS NULL THEN

        RAISE EXCEPTION 'json is mandatory';

    END IF;



------------------------------------------------------------------

-- Validate JSON Structure

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

        'draftedData must be empty';

END IF;



------------------------------------------------------------------

-- Extract Metadata

------------------------------------------------------------------

v_sign_off_type :=

    TRIM(

        p_json -> 'metadata' ->> 'signOffType'

    );



v_name :=

    TRIM(

        p_json -> 'metadata' ->> 'name'

    );



v_ms_id :=

    NULLIF(

        p_json -> 'metadata' ->> 'msId',

        ''

    )::BIGINT;



v_task_name :=

    TRIM(

        p_json -> 'metadata' ->> 'taskName'

    );



v_timesheet :=

    p_json -> 'metadata' -> 'timesheet';



v_quantity :=

    NULLIF(

        p_json -> 'metadata' ->> 'quantity',

        ''

    )::NUMERIC;







    ------------------------------------------------------------------

-- Validate Fields

------------------------------------------------------------------

IF COALESCE(v_sign_off_type, '') = '' THEN

    RAISE EXCEPTION 'signOffType is mandatory';

END IF;



IF COALESCE(v_name, '') = '' THEN

    RAISE EXCEPTION 'name is mandatory';

END IF;



------------------------------------------------------------------

-- Per Hour Validation

------------------------------------------------------------------

IF v_sign_off_type = 'Per Hour' THEN



    IF v_timesheet IS NULL

       OR jsonb_typeof(v_timesheet) <> 'array'

       OR jsonb_array_length(v_timesheet) = 0

    THEN

        RAISE EXCEPTION

            'At least one timesheet entry is required for Per Hour sign-off';

    END IF;



    IF COALESCE(TRIM(v_task_name), '') = '' THEN

        RAISE EXCEPTION

            'taskName is mandatory';

    END IF;



    IF v_quantity IS NULL

       OR v_quantity <= 0

    THEN

        RAISE EXCEPTION

            'quantity must be a positive number';

    END IF;



------------------------------------------------------------------

-- Microservice Validation

------------------------------------------------------------------

ELSE



    IF v_ms_id IS NULL

       OR v_ms_id <= 0

    THEN

        RAISE EXCEPTION

            'msId is mandatory';

    END IF;



    IF v_quantity IS NULL

       OR v_quantity <= 0

       OR v_quantity <> floor(v_quantity)

    THEN

        RAISE EXCEPTION

            'quantity must be a positive whole number';

    END IF;



END IF;



    ------------------------------------------------------------------

    -- Resolve Session User

    ------------------------------------------------------------------

    v_user_uuid := current_setting('app.CURRENT_USER_ID', TRUE)::UUID;



    SELECT u.in_record_id

    INTO v_created_by

    FROM public.users u

    WHERE u.user_id = v_user_uuid;



    IF v_created_by IS NULL THEN

        RAISE EXCEPTION 'Unable to resolve session user';

    END IF;



    ------------------------------------------------------------------

    -- Resolve Parent Request

    ------------------------------------------------------------------

    SELECT r.ref_requests_in_record_id_immediate_parent

    INTO v_immediate_parent_request_id

    FROM public.requests r

    WHERE r.in_record_id = p_request_id;



    IF v_immediate_parent_request_id IS NULL THEN

        RAISE EXCEPTION 'Immediate parent request not found';

    END IF;



    ------------------------------------------------------------------

    -- Get Request Owner (Professional)

    ------------------------------------------------------------------

    SELECT owner

    INTO v_professional_id

    FROM public.requests

    WHERE in_record_id = p_request_id;



    IF v_professional_id IS NULL THEN

        RAISE EXCEPTION 'Request owner not found';

    END IF;



    ------------------------------------------------------------------

    -- Create Actionable

    ------------------------------------------------------------------

    INSERT INTO public.actionables (

        actionable_name,

        actionable_category,

        request_subject,

        ref_requests_in_record_id,

        actionable_description,

        created_by,

        actionable_creation_time

    )

    VALUES (

        'Sign Off',

        'Billing',

        p_request_id,

        p_request_id,

        p_description,

        v_created_by,

        NOW()

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

        step_metadata

    )

    VALUES (

        v_actionable_id,

        p_request_id,

        1,

        'Planned',

        p_json

    )

    RETURNING in_record_id INTO v_step_1_id;



    ------------------------------------------------------------------

    -- Update Step 1 to Open

    ------------------------------------------------------------------

    UPDATE public.actionables_steps

    SET status = 'Open'

    WHERE in_record_id = v_step_1_id;



    ------------------------------------------------------------------

    -- Create Step 2

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

        v_immediate_parent_request_id,

        2,

        'Open',

        p_step_2_json

    )

    RETURNING in_record_id INTO v_step_2_id;



    ------------------------------------------------------------------

    -- Handle PER_HOUR Sign-Off

    ------------------------------------------------------------------

    IF v_sign_off_type = 'Per Hour' THEN

        FOR ts IN

    SELECT *

    FROM jsonb_array_elements(v_timesheet)

LOOP



    v_existing_timesheet_id :=

        CASE

            WHEN ts ? 'id'

                 AND ts ->> 'id' IS NOT NULL

                 AND trim(ts ->> 'id') <> ''

            THEN (ts ->> 'id')::bigint

            ELSE NULL

        END;



    v_from_date := ts ->> 'fromDate';

    v_from_time := ts ->> 'fromTime';

    v_to_date := ts ->> 'toDate';

    v_to_time := ts ->> 'toTime';

    v_desc := ts ->> 'description';



    v_from_dt := ROW(v_from_date::DATE, v_from_time::TIME)::DATE_TIME;

    v_to_dt   := ROW(v_to_date::DATE, v_to_time::TIME)::DATE_TIME;



    SELECT *

    INTO

        v_timesheet_id,

        v_calculated_hours

    FROM public.app_sign_off_create_timesheet_v_0_0_1(

        p_request_id,

        v_professional_id,

        v_actionable_id,

        v_step_1_id,

        v_task_name,

        v_from_dt,

        v_to_dt,

        v_desc,

        v_existing_timesheet_id

    );



    v_total_calculated_hours :=

        v_total_calculated_hours + v_calculated_hours;



END LOOP;

IF ABS(v_total_calculated_hours - v_quantity) > 0.0001 THEN

    RAISE EXCEPTION

        'Timesheet hours (%) do not match requested quantity (%)',

        v_total_calculated_hours,

        v_quantity;

END IF;

    ------------------------------------------------------------------

    -- Handle Microservice-Based Sign-Off (PER_UNIT / PER_REQUEST)

    ------------------------------------------------------------------

    ELSE

        IF (

            SELECT COUNT(*)

            FROM usage u

            WHERE u.ref_requests_in_record_id = p_request_id

              AND u.ref_services_sku_in_record_id = v_ms_id

              AND u.status = 'Delivery In Progress'

        ) < v_quantity THEN

            RAISE EXCEPTION

                'Requested quantity % exceeds available Delivery In Progress quantity for microservice %',

                v_quantity,

                v_ms_id;

        END IF;



        -- Reserve Usage Records For Sign Off

        UPDATE usage u

        SET status = 'Pending Sign-Off'

        WHERE u.in_record_id IN (

            SELECT uu.in_record_id

            FROM usage uu

            WHERE uu.ref_requests_in_record_id = p_request_id

              AND uu.ref_services_sku_in_record_id = v_ms_id

              AND uu.status = 'Delivery In Progress'

            ORDER BY uu.in_record_id

            LIMIT v_quantity::INT

        );

    END IF;



    ------------------------------------------------------------------

    -- Complete Step 1

    ------------------------------------------------------------------

    UPDATE public.actionables_steps

    SET

        status = 'Complete',

        ref_users_in_record_id_completed_by = v_created_by

    WHERE in_record_id = v_step_1_id;



    ------------------------------------------------------------------

    -- Return

    ------------------------------------------------------------------

    RETURN QUERY

    SELECT

        v_actionable_id,

        v_step_1_id,

        v_step_2_id,

        p_request_id,

        'STEP_1_COMPLETE'::TEXT;



END;

$function$