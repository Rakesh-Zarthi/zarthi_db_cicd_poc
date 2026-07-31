CREATE OR REPLACE FUNCTION public.app_sign_off_sync_timesheet_status(p_actionable_id bigint, p_step_no custom_number, p_delivery_decision text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Step 1

------------------------------------------------------------------

v_step_1_id bigint;



BEGIN



------------------------------------------------------------------

-- Resolve Step 1

------------------------------------------------------------------

SELECT ast.in_record_id

INTO v_step_1_id

FROM public.actionables_steps ast

WHERE ast.ref_actionables_in_record_id = p_actionable_id

  AND ast.step_no = 1;



IF v_step_1_id IS NULL THEN

    RETURN;

END IF;



------------------------------------------------------------------

-- STEP 2 -> NOT DELIVERED

------------------------------------------------------------------

IF p_step_no = 2

   AND trim(initcap(lower(p_delivery_decision))) = 'Not Delivered'

THEN



    --------------------------------------------------------------

    -- Re-open Timesheet

    --------------------------------------------------------------

    UPDATE public.timesheet

    SET status = 'Open'

    WHERE ref_actionables_steps_in_record_id = v_step_1_id;



    --------------------------------------------------------------

    -- Remove Usage Mapping

    --------------------------------------------------------------

    UPDATE public.timesheet_usage tu

    SET ref_usage_in_record_id = NULL

    FROM public.timesheet t

    WHERE t.in_record_id = tu.ref_timesheet_in_record_id

      AND t.ref_actionables_steps_in_record_id = v_step_1_id;



    RETURN;



END IF;



------------------------------------------------------------------

-- STEP 3 -> DELIVERED

------------------------------------------------------------------

IF p_step_no = 3

   AND trim(initcap(lower(p_delivery_decision))) = 'Delivered'

THEN



    UPDATE public.timesheet

    SET status = 'Approve'

    WHERE ref_actionables_steps_in_record_id = v_step_1_id;



    RETURN;



END IF;



------------------------------------------------------------------

-- STEP 3 -> NOT DELIVERED

------------------------------------------------------------------

IF p_step_no = 3

   AND trim(initcap(lower(p_delivery_decision))) = 'Not Delivered'

THEN



    --------------------------------------------------------------

    -- Re-open Timesheet

    --------------------------------------------------------------

    UPDATE public.timesheet

    SET status = 'Open'

    WHERE ref_actionables_steps_in_record_id = v_step_1_id;



    --------------------------------------------------------------

    -- Remove Usage Mapping

    --------------------------------------------------------------

    UPDATE public.timesheet_usage tu

    SET ref_usage_in_record_id = NULL

    FROM public.timesheet t

    WHERE t.in_record_id = tu.ref_timesheet_in_record_id

      AND t.ref_actionables_steps_in_record_id = v_step_1_id;



    RETURN;



END IF;



END;

$function$