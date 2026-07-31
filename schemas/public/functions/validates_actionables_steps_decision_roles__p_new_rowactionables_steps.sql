CREATE OR REPLACE FUNCTION public.validates_actionables_steps_decision_roles(p_new_row actionables_steps)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

v_actionable_name text;

v_step2_decision  text;

BEGIN





------------------------------------------------------------------

-- Resolve actionable

------------------------------------------------------------------

SELECT actionable_name

INTO v_actionable_name

FROM public.actionables

WHERE in_record_id = p_new_row.ref_actionables_in_record_id;



IF NOT FOUND THEN

    RAISE EXCEPTION

        'Actionable % not found',

        p_new_row.ref_actionables_in_record_id

        USING ERRCODE = '23514';

END IF;



------------------------------------------------------------------

-- Apply only for:

-- Add Microservice Quantity

-- Add Microservice Quantity (Bulk)

------------------------------------------------------------------

IF v_actionable_name NOT IN (

    'Add Microservice Quantity',

    'Add Microservice Quantity (Bulk)','Add Orders'

) THEN

    RETURN;

END IF;



------------------------------------------------------------------

-- delivery_decision allowed ONLY on Step-2 / Step-3

------------------------------------------------------------------

IF p_new_row.delivery_decision IS NOT NULL

   AND p_new_row.step_no NOT IN (2, 3) THEN



    RAISE EXCEPTION

        'delivery_decision allowed only on Step-2 or Step-3'

        USING ERRCODE = '23514';



END IF;



------------------------------------------------------------------

-- delivery_decision requires Complete

------------------------------------------------------------------

IF p_new_row.delivery_decision IS NOT NULL

   AND p_new_row.status <> 'Complete' THEN



    RAISE EXCEPTION

        'delivery_decision can only be set when step is Complete'

        USING ERRCODE = '23514';



END IF;



------------------------------------------------------------------

-- Step-2 / Step-3 Complete requires decision

------------------------------------------------------------------

IF p_new_row.step_no IN (2, 3)

   AND p_new_row.status = 'Complete'

   AND p_new_row.delivery_decision IS NULL THEN



    RAISE EXCEPTION

        'Step-% must provide delivery_decision',

        p_new_row.step_no

        USING ERRCODE = '23514';



END IF;



------------------------------------------------------------------

-- Allowed decisions

------------------------------------------------------------------

IF p_new_row.delivery_decision IS NOT NULL

   AND p_new_row.delivery_decision NOT IN (

        'Approve',

        'Reject'

   ) THEN



    RAISE EXCEPTION

        'delivery_decision must be Approve or Reject'

        USING ERRCODE = '23514';



END IF;



------------------------------------------------------------------

-- STEP-3 requires valid STEP-2

------------------------------------------------------------------

IF p_new_row.step_no = 3 THEN



    SELECT delivery_decision

    INTO v_step2_decision

    FROM public.actionables_steps

    WHERE ref_actionables_in_record_id =

          p_new_row.ref_actionables_in_record_id

      AND step_no = 2;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Step-2 must exist before completing Step-3'

            USING ERRCODE = '23514';

    END IF;



END IF;



------------------------------------------------------------------

-- STEP-3 consistency:

-- Step-3 allowed ONLY if Step-2 = Approve

------------------------------------------------------------------

IF p_new_row.step_no = 3

   AND p_new_row.status = 'Complete'

   AND v_step2_decision <> 'Approve' THEN



    RAISE EXCEPTION

        'Step-3 can complete only when Step-2 delivery_decision = Approve'

        USING ERRCODE = '23514';



END IF;



------------------------------------------------------------------

-- Reject at Step-2 ΓçÆ Step-3 must be Discard

------------------------------------------------------------------

IF p_new_row.step_no = 3

   AND v_step2_decision = 'Reject'

   AND p_new_row.status <> 'Discard' THEN



    RAISE EXCEPTION

        'Step-3 must be Discard when Step-2 delivery_decision = Reject'

        USING ERRCODE = '23514';



END IF;





END;$function$