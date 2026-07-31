CREATE OR REPLACE FUNCTION public.trg_add_microservice_usage_status_sync()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$



DECLARE





------------------------------------------------------------------

-- Actionable

------------------------------------------------------------------

v_actionable_name text;

v_actionable_category text;

v_request_id bigint;

v_module text;





------------------------------------------------------------------

-- Sign Off

------------------------------------------------------------------

v_sign_off_type text;

v_ms_id bigint;

v_task_name text;

v_quantity numeric;

v_pending_count numeric;





BEGIN





------------------------------------------------------------------

-- Fire only on completion

------------------------------------------------------------------

IF NEW.status <> 'Complete' THEN

    RETURN NEW;

END IF;



------------------------------------------------------------------

-- Resolve Actionable + Request

------------------------------------------------------------------

SELECT

    initcap(lower(trim(a.actionable_name))),

    initcap(lower(trim(a.actionable_category))),

    a.request_subject,

    initcap(lower(trim(r.module)))

INTO

    v_actionable_name,

    v_actionable_category,

    v_request_id,

    v_module

FROM public.actionables a

INNER JOIN public.requests r

    ON r.in_record_id = a.request_subject

WHERE a.in_record_id =

      NEW.ref_actionables_in_record_id;



IF NOT FOUND THEN

    RETURN NEW;

END IF;



------------------------------------------------------------------

-- Only Roles Module

------------------------------------------------------------------

IF v_module <> 'Roles' THEN

    RETURN NEW;

END IF;



------------------------------------------------------------------

-- Add Microservice Quantity & Add Orders

------------------------------------------------------------------

IF v_actionable_name IN (

       'Add Microservice Quantity',

       'Add Orders'

   )

   AND v_actionable_category = 'Orders'

THEN



    --------------------------------------------------------------

    -- STEP 2 REJECT

    --------------------------------------------------------------

    IF NEW.step_no = 2

       AND NEW.delivery_decision = 'Reject'

    THEN



        UPDATE public.usage

        SET status = 'Rejected'

        WHERE ref_requests_in_record_id = v_request_id

          AND ref_actionables_in_record_immediate_consumer =

              NEW.ref_actionables_in_record_id

          AND status = 'Commercial Approval Pending';



        RETURN NEW;



    END IF;



    --------------------------------------------------------------

    -- STEP 3 APPROVE

    --------------------------------------------------------------

    IF NEW.step_no = 3

       AND NEW.delivery_decision = 'Approve'

    THEN



        UPDATE public.usage

        SET status = 'Delivery In Progress'

        WHERE ref_requests_in_record_id = v_request_id

          AND ref_actionables_in_record_immediate_consumer =

              NEW.ref_actionables_in_record_id

          AND status = 'Commercial Approval Pending';



        RETURN NEW;



    END IF;



    --------------------------------------------------------------

    -- STEP 3 REJECT

    --------------------------------------------------------------

    IF NEW.step_no = 3

       AND NEW.delivery_decision = 'Reject'

    THEN



        UPDATE public.usage

        SET status = 'Rejected'

        WHERE ref_requests_in_record_id = v_request_id

          AND ref_actionables_in_record_immediate_consumer =

              NEW.ref_actionables_in_record_id

          AND status = 'Commercial Approval Pending';



        RETURN NEW;



    END IF;



    RETURN NEW;



END IF;



------------------------------------------------------------------

-- Sign Off

------------------------------------------------------------------

IF v_actionable_name = 'Sign Off'

   AND v_actionable_category = 'Billing'

THEN



    --------------------------------------------------------------

    -- Resolve Step 1 Metadata

    --------------------------------------------------------------

SELECT

    trim(ast.step_metadata -> 'metadata' ->> 'signOffType'),

    NULLIF(ast.step_metadata -> 'metadata' ->> 'msId','')::bigint,

    trim(ast.step_metadata -> 'metadata' ->> 'taskName'),

    NULLIF(ast.step_metadata -> 'metadata' ->> 'quantity','')::numeric

INTO

    v_sign_off_type,

    v_ms_id,

    v_task_name,

    v_quantity

FROM public.actionables_steps ast

WHERE ast.ref_actionables_in_record_id =

      NEW.ref_actionables_in_record_id

  AND ast.step_no = 1;



IF v_sign_off_type = 'Per Hour' THEN



    IF COALESCE(v_task_name,'') = ''

       OR v_quantity IS NULL

    THEN

        RETURN NEW;

    END IF;



ELSE



    IF v_ms_id IS NULL

       OR v_quantity IS NULL

    THEN

        RETURN NEW;

    END IF;



END IF;



  --------------------------------------------------------------

-- Skip validation for Step 1

-- Step 1 itself creates the Pending Sign-Off records

--------------------------------------------------------------

IF NEW.step_no IN (2,3) THEN



IF v_sign_off_type = 'Per Hour' THEN



    SELECT COALESCE(SUM(quantity),0)

    INTO v_pending_count

    FROM public.usage u

    WHERE u.ref_requests_in_record_id = v_request_id

      AND u.task = v_task_name

      AND u.status = 'Pending Sign-Off';



ELSE



    SELECT COALESCE(SUM(quantity),0)

    INTO v_pending_count

    FROM public.usage u

    WHERE u.ref_requests_in_record_id = v_request_id

      AND u.ref_services_sku_in_record_id = v_ms_id

      AND u.status = 'Pending Sign-Off';



END IF;



       IF v_pending_count < v_quantity THEN



    IF v_sign_off_type = 'Per Hour' THEN



        RAISE EXCEPTION

            'Expected % Pending Sign-Off hours but found % for request % and task %',

            v_quantity,

            v_pending_count,

            v_request_id,

            v_task_name;



    ELSE



        RAISE EXCEPTION

            'Expected % Pending Sign-Off records but found % for request % and sku %',

            v_quantity,

            v_pending_count,

            v_request_id,

            v_ms_id;



    END IF;



END IF;

   END IF;

--------------------------------------------------------------

-- STEP 2 NOT DELIVERED

--------------------------------------------------------------

IF NEW.step_no = 2

   AND NEW.delivery_decision = 'Not Delivered'

THEN



IF v_sign_off_type = 'Per Hour' THEN



UPDATE public.usage u

SET status = 'Delivery In Progress'

WHERE u.in_record_id IN (

    SELECT tu.ref_usage_in_record_id

    FROM public.timesheet t

    INNER JOIN public.timesheet_usage tu

        ON tu.ref_timesheet_in_record_id = t.in_record_id

    WHERE t.ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

      AND tu.ref_usage_in_record_id IS NOT NULL

);



PERFORM public.app_sign_off_sync_timesheet_status(

    NEW.ref_actionables_in_record_id,

    NEW.step_no,

    NEW.delivery_decision

);



ELSE



    UPDATE public.usage u

    SET status = 'Delivery In Progress'

    WHERE u.in_record_id IN (

        SELECT uu.in_record_id

        FROM public.usage uu

        WHERE uu.ref_requests_in_record_id = v_request_id

          AND uu.ref_services_sku_in_record_id = v_ms_id

          AND uu.status = 'Pending Sign-Off'

        ORDER BY uu.in_record_id

        LIMIT v_quantity::integer

    );



END IF;

END IF;

--------------------------------------------------------------

-- STEP 3 DELIVERED

--------------------------------------------------------------

IF NEW.step_no = 3

   AND NEW.delivery_decision = 'Delivered'

THEN



IF v_sign_off_type = 'Per Hour' THEN



UPDATE public.usage u

SET status = 'Delivered'

WHERE u.in_record_id IN (

    SELECT tu.ref_usage_in_record_id

    FROM public.timesheet t

    INNER JOIN public.timesheet_usage tu

        ON tu.ref_timesheet_in_record_id = t.in_record_id

    WHERE t.ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

      AND tu.ref_usage_in_record_id IS NOT NULL

);



PERFORM public.app_sign_off_sync_timesheet_status(

    NEW.ref_actionables_in_record_id,

    NEW.step_no,

    NEW.delivery_decision

);



ELSE



    UPDATE public.usage u

    SET status = 'Delivered'

    WHERE u.in_record_id IN (

        SELECT uu.in_record_id

        FROM public.usage uu

        WHERE uu.ref_requests_in_record_id = v_request_id

          AND uu.ref_services_sku_in_record_id = v_ms_id

          AND uu.status = 'Pending Sign-Off'

        ORDER BY uu.in_record_id

        LIMIT v_quantity::integer

    );



END IF;

END IF;



--------------------------------------------------------------

-- STEP 3 NOT DELIVERED

--------------------------------------------------------------

IF NEW.step_no = 3

   AND NEW.delivery_decision = 'Not Delivered'

THEN



IF v_sign_off_type = 'Per Hour' THEN



UPDATE public.usage u

SET status = 'Delivery In Progress'

WHERE u.in_record_id IN (

    SELECT tu.ref_usage_in_record_id

    FROM public.timesheet t

    INNER JOIN public.timesheet_usage tu

        ON tu.ref_timesheet_in_record_id = t.in_record_id

    WHERE t.ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

      AND tu.ref_usage_in_record_id IS NOT NULL

);



PERFORM public.app_sign_off_sync_timesheet_status(

    NEW.ref_actionables_in_record_id,

    NEW.step_no,

    NEW.delivery_decision

);



ELSE



    UPDATE public.usage u

    SET status = 'Delivery In Progress'

    WHERE u.in_record_id IN (

        SELECT uu.in_record_id

        FROM public.usage uu

        WHERE uu.ref_requests_in_record_id = v_request_id

          AND uu.ref_services_sku_in_record_id = v_ms_id

          AND uu.status = 'Pending Sign-Off'

        ORDER BY uu.in_record_id

        LIMIT v_quantity::integer

    );



END IF;



    RETURN NEW;



END IF;

END IF;



RETURN NEW;





END;

$function$