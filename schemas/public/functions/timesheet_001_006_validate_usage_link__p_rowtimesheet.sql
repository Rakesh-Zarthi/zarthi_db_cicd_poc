CREATE OR REPLACE FUNCTION public.timesheet_001_006_validate_usage_link(p_row timesheet)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_usage_request_id bigint;

    v_usage_status     text;

BEGIN

    ------------------------------------------------------------------

    -- Only validate if usage is linked

    ------------------------------------------------------------------

    IF p_row.ref_usage_in_record_id IS NULL THEN

        RETURN;

    END IF;



    ------------------------------------------------------------------

    -- Fetch usage (must exist exactly once)

    ------------------------------------------------------------------

    SELECT u.ref_requests_in_record_id,

           u.status

    INTO v_usage_request_id,

         v_usage_status

    FROM public."usage" u

    WHERE u.in_record_id = p_row.ref_usage_in_record_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Γ¥î Invalid usage reference.';

    END IF;



    ------------------------------------------------------------------

    -- Validate status presence

    ------------------------------------------------------------------

    IF v_usage_status IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Usage % has invalid NULL status.',

            p_row.ref_usage_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- Normalize once

    ------------------------------------------------------------------

    v_usage_status := initcap(lower(trim(v_usage_status)));



    ------------------------------------------------------------------

    -- Validate request consistency

    ------------------------------------------------------------------

    IF v_usage_request_id <> p_row.ref_requests_in_record_id_request THEN

        RAISE EXCEPTION

            'Γ¥î Timesheet request must match usage request.';

    END IF;



    ------------------------------------------------------------------

    -- Prevent linking to invalid usage states

    ------------------------------------------------------------------

    IF v_usage_status IN ('Cancelled', 'Billed') THEN

        RAISE EXCEPTION

            'Γ¥î Cannot link timesheet to % usage %.',

            v_usage_status,

            p_row.ref_usage_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- ≡ƒÜ¿ Enforce Approved consistency

    ------------------------------------------------------------------

    IF v_usage_status = 'Approved'

       AND p_row.status <> 'Approve' THEN

        RAISE EXCEPTION

            'Γ¥î Cannot create/update timesheet: usage % is already Approved.',

            p_row.ref_usage_in_record_id;

    END IF;



END;

$function$