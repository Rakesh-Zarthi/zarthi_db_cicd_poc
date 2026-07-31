CREATE OR REPLACE FUNCTION public.usage_status_validation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE



    v_old_status text :=

        initcap(lower(trim(OLD.status)));



    v_new_status text :=

        initcap(lower(trim(NEW.status)));



    v_req_module text;



BEGIN



    ------------------------------------------------------------------

    -- Only act when status changes

    ------------------------------------------------------------------

    IF v_old_status IS NOT DISTINCT FROM v_new_status THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Resolve request module

    ------------------------------------------------------------------

    SELECT

        initcap(lower(trim(r.module)))

    INTO v_req_module

    FROM public.requests r

    WHERE r.in_record_id = NEW.ref_requests_in_record_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid request reference.';

    END IF;



    ------------------------------------------------------------------

    ------------------------------------------------------------------

    -- SERVICES + STAFFING

    -- OLD FLOW PRESERVED EXACTLY

    ------------------------------------------------------------------

    ------------------------------------------------------------------

    IF v_req_module IN ('Services', 'Staffing') THEN



        ------------------------------------------------------------------

        -- TERMINAL STATES

        ------------------------------------------------------------------



        -- Billed ΓåÆ immutable

        IF v_old_status = 'Billed'

           AND v_new_status <> 'Billed'

        THEN

            RAISE EXCEPTION

                'Γ¥î Usage % is already Billed and cannot change status.',

                OLD.in_record_id;

        END IF;



        -- Cancelled ΓåÆ immutable

        IF v_old_status = 'Cancelled'

           AND v_new_status <> 'Cancelled'

        THEN

            RAISE EXCEPTION

                'Γ¥î Usage % is Cancelled and cannot be reactivated.',

                OLD.in_record_id;

        END IF;



        ------------------------------------------------------------------

        -- FSM RULES

        ------------------------------------------------------------------



        -- Awaiting ΓåÆ only Approved / Cancelled

        IF v_old_status = 'Awaiting Approval'

           AND v_new_status NOT IN (

                'Approved',

                'Cancelled'

           )

        THEN

            RAISE EXCEPTION

                'Γ¥î Invalid transition from Awaiting Approval to %.',

                v_new_status;

        END IF;



        -- Approved ΓåÆ only Approved / Billed

        IF v_old_status = 'Approved'

           AND v_new_status NOT IN (

                'Approved',

                'Billed'

           )

        THEN

            RAISE EXCEPTION

                'Γ¥î Usage % cannot move from Approved to %.',

                OLD.in_record_id,

                v_new_status;

        END IF;



        ------------------------------------------------------------------

        -- STATE DEPENDENCIES

        ------------------------------------------------------------------



        -- Cancel ΓåÆ must not have timesheets

        IF v_new_status = 'Cancelled' THEN



            PERFORM 1

            FROM public.timesheet t

            WHERE t.ref_usage_in_record_id =

                  NEW.in_record_id

            FOR UPDATE;



            IF FOUND THEN

                RAISE EXCEPTION

                    'Γ¥î Cannot cancel usage %: timesheets are still linked.',

                    NEW.in_record_id;

            END IF;



        END IF;



        -- Approve ΓåÆ all timesheets must be Approved

        IF v_new_status = 'Approved' THEN



            PERFORM 1

            FROM public.timesheet t

            WHERE t.ref_usage_in_record_id =

                  NEW.in_record_id

              AND t.status <> 'Approve'

            FOR UPDATE;



            IF FOUND THEN

                RAISE EXCEPTION

                    'Γ¥î Cannot approve usage %: all linked timesheets must be Approved.',

                    NEW.in_record_id;

            END IF;



        END IF;



    END IF;



    ------------------------------------------------------------------

    ------------------------------------------------------------------

    -- ROLES FLOW

    ------------------------------------------------------------------

    ------------------------------------------------------------------

    IF v_req_module = 'Roles' THEN



------------------------------------------------------------------

-- ROLES : Commercial Approval Pending -> Delivery In Progress

------------------------------------------------------------------

IF v_old_status = 'Commercial Approval Pending'

   AND v_new_status = 'Delivery In Progress'

THEN



    ------------------------------------------------------------------

    -- Step-2 must be Complete + Approve

    ------------------------------------------------------------------

    IF NOT EXISTS (



        SELECT 1

        FROM public.actionables a

        JOIN public.actionables_steps ast

             ON ast.ref_actionables_in_record_id =

                a.in_record_id



        WHERE a.request_subject =

              NEW.ref_requests_in_record_id



          AND initcap(lower(trim(a.actionable_name)))

              IN (

                    'Add Microservice Quantity',

                    'Add Microservice Quantity (Bulk)','Add Orders'

                 )



          AND ast.step_no = 2

          AND ast.status = 'Complete'

          AND ast.delivery_decision = 'Approve'



    )

    THEN

        RAISE EXCEPTION

            'Step-2 must be Complete + Approve before usage can move to Delivery In Progress.';

    END IF;



    ------------------------------------------------------------------

    -- Step-3 must be Complete + Approve

    ------------------------------------------------------------------

    IF NOT EXISTS (



        SELECT 1

        FROM public.actionables a

        JOIN public.actionables_steps ast

             ON ast.ref_actionables_in_record_id =

                a.in_record_id



        WHERE a.request_subject =

              NEW.ref_requests_in_record_id



          AND initcap(lower(trim(a.actionable_name)))

              IN (

                    'Add Microservice Quantity',

                    'Add Microservice Quantity (Bulk)', 'Add Orders'

                 )



          AND ast.step_no = 3

          AND ast.status = 'Complete'

          AND ast.delivery_decision = 'Approve'



    )

    THEN

        RAISE EXCEPTION

            'Step-3 must be Complete + Approve before usage can move to Delivery In Progress.';

    END IF;



END IF;



------------------------------------------------------------------

-- ROLES : Commercial Approval Pending -> Rejected

------------------------------------------------------------------

IF v_old_status = 'Commercial Approval Pending'

   AND v_new_status = 'Rejected'

THEN



    ------------------------------------------------------------------

    -- CASE-1

    -- Step-2 Rejected

    ------------------------------------------------------------------

    IF EXISTS (



        SELECT 1

        FROM public.actionables a

        JOIN public.actionables_steps ast

             ON ast.ref_actionables_in_record_id =

                a.in_record_id



        WHERE a.request_subject =

              NEW.ref_requests_in_record_id



          AND initcap(lower(trim(a.actionable_name)))

              IN (

                    'Add Microservice Quantity',

                    'Add Microservice Quantity (Bulk)','Add Orders'

                 )



          AND ast.step_no = 2

          AND ast.status = 'Complete'

          AND ast.delivery_decision = 'Reject'



    )

    THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- CASE-2

    -- Step-2 Approve + Step-3 Reject

    ------------------------------------------------------------------

    IF EXISTS (



        SELECT 1

        FROM public.actionables a



        JOIN public.actionables_steps ast2

             ON ast2.ref_actionables_in_record_id =

                a.in_record_id



        JOIN public.actionables_steps ast3

             ON ast3.ref_actionables_in_record_id =

                a.in_record_id



        WHERE a.request_subject =

              NEW.ref_requests_in_record_id



          AND initcap(lower(trim(a.actionable_name)))

              IN (

                    'Add Microservice Quantity',

                    'Add Microservice Quantity (Bulk)','Add Orders'

                 )



          AND ast2.step_no = 2

          AND ast2.status = 'Complete'

          AND ast2.delivery_decision = 'Approve'



          AND ast3.step_no = 3

          AND ast3.status = 'Complete'

          AND ast3.delivery_decision = 'Reject'



    )

    THEN

        RETURN NEW;

    END IF;



    RAISE EXCEPTION

        'Commercial Approval Pending can move to Rejected only through a valid approval rejection workflow.';



END IF;





------------------------------------------------------------------

-- ROLES : Delivery In Progress -> Pending Sign-Off

------------------------------------------------------------------

IF v_old_status = 'Delivery In Progress'

   AND v_new_status = 'Pending Sign-Off'

THEN



    ------------------------------------------------------------------

    -- Validate Sign Off actionable exists

    ------------------------------------------------------------------

    IF NOT EXISTS (



        SELECT 1

        FROM public.actionables a

        WHERE a.request_subject =

              NEW.ref_requests_in_record_id

          AND initcap(lower(trim(a.actionable_name)))

                = 'Sign Off'



    )

    THEN

        RAISE EXCEPTION

            'Sign Off actionable not found for request %.',

            NEW.ref_requests_in_record_id;

    END IF;



    ------------------------------------------------------------------

-- Validate sufficient In Progress quantity exists

-- Backend must pick OLDEST rows

------------------------------------------------------------------

PERFORM 1

FROM (

    SELECT u.in_record_id

    FROM public.usage u

    WHERE u.ref_requests_in_record_id =

          NEW.ref_requests_in_record_id



      AND (

            ------------------------------------------------------------------

            -- SKU based Sign Off

            ------------------------------------------------------------------

            (

                NEW.ref_services_sku_in_record_id IS NOT NULL

                AND u.ref_services_sku_in_record_id =

                    NEW.ref_services_sku_in_record_id

            )



            OR



            ------------------------------------------------------------------

            -- Task based (Per Hour) Sign Off

            ------------------------------------------------------------------

            (

                NEW.ref_services_sku_in_record_id IS NULL

                AND COALESCE(TRIM(u.task), '') =

                    COALESCE(TRIM(NEW.task), '')

            )

          )



      AND u.status = 'Delivery In Progress'



    ORDER BY

        u.in_added_time ASC,

        u.in_record_id ASC

) x;



IF NOT FOUND THEN

    RAISE EXCEPTION

        'No Delivery In Progress quantity available for Sign Off.';

END IF;



END IF;



------------------------------------------------------------------

-- ROLES : Pending Sign-Off -> Delivered

------------------------------------------------------------------

IF v_old_status = 'Pending Sign-Off'

   AND v_new_status = 'Delivered'

THEN



    ------------------------------------------------------------------

    -- Validate Step-2 Delivered

    ------------------------------------------------------------------

    IF NOT EXISTS (



        SELECT 1

        FROM public.actionables a

        JOIN public.actionables_steps ast

             ON ast.ref_actionables_in_record_id =

                a.in_record_id



        WHERE a.request_subject =

              NEW.ref_requests_in_record_id



          AND initcap(lower(trim(a.actionable_name)))

                = 'Sign Off'



          AND ast.step_no = 2

          AND ast.status = 'Complete'

          AND ast.delivery_decision = 'Delivered'



    )

    THEN

        RAISE EXCEPTION

            'Step-2 must be Complete + Delivered before usage can become Delivered.';

    END IF;



    ------------------------------------------------------------------

    -- Validate Step-3 Delivered

    ------------------------------------------------------------------

    IF NOT EXISTS (



        SELECT 1

        FROM public.actionables a

        JOIN public.actionables_steps ast

             ON ast.ref_actionables_in_record_id =

                a.in_record_id



        WHERE a.request_subject =

              NEW.ref_requests_in_record_id



          AND initcap(lower(trim(a.actionable_name)))

                = 'Sign Off'



          AND ast.step_no = 3

          AND ast.status = 'Complete'

          AND ast.delivery_decision = 'Delivered'



    )

    THEN

        RAISE EXCEPTION

            'Step-3 must be Complete + Delivered before usage can become Delivered.';

    END IF;



END IF;



------------------------------------------------------------------

-- ROLES : Pending Sign-Off -> Delivery In Progress

------------------------------------------------------------------

IF v_old_status = 'Pending Sign-Off'

   AND v_new_status = 'Delivery In Progress'

THEN



    ------------------------------------------------------------------

    -- CASE-1

    -- Step-2 Not Delivered

    ------------------------------------------------------------------

    IF EXISTS (



        SELECT 1

        FROM public.actionables a

        JOIN public.actionables_steps ast2

             ON ast2.ref_actionables_in_record_id =

                a.in_record_id



        LEFT JOIN public.actionables_steps ast3

               ON ast3.ref_actionables_in_record_id =

                  a.in_record_id

              AND ast3.step_no = 3



        WHERE a.request_subject =

              NEW.ref_requests_in_record_id



          AND initcap(lower(trim(a.actionable_name)))

                = 'Sign Off'



          AND ast2.step_no = 2

          AND ast2.status = 'Complete'

          AND ast2.delivery_decision = 'Not Delivered'



          AND (

                ast3.status = 'Discard'

                OR ast3.in_record_id IS NULL

          )



    )

    THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- CASE-2

    -- Step-3 Not Delivered

    ------------------------------------------------------------------

    IF EXISTS (



        SELECT 1

        FROM public.actionables a



        JOIN public.actionables_steps ast2

             ON ast2.ref_actionables_in_record_id =

                a.in_record_id



        JOIN public.actionables_steps ast3

             ON ast3.ref_actionables_in_record_id =

                a.in_record_id



        WHERE a.request_subject =

              NEW.ref_requests_in_record_id



          AND initcap(lower(trim(a.actionable_name)))

                = 'Sign Off'



          AND ast2.step_no = 2

          AND ast2.status = 'Complete'

          AND ast2.delivery_decision = 'Delivered'



          AND ast3.step_no = 3

          AND ast3.status = 'Complete'

          AND ast3.delivery_decision = 'Not Delivered'



    )

    THEN

        RETURN NEW;

    END IF;



    RAISE EXCEPTION

        'Pending Sign-Off can return to Delivery In Progress only through valid Not Delivered workflow.';



END IF;



------------------------------------------------------------------

-- ROLES : Delivery In Progress -> Cancelled

------------------------------------------------------------------

IF v_new_status = 'Cancelled'

THEN

    IF v_old_status <> 'Delivery In Progress' THEN

        RAISE EXCEPTION

            'Invalid usage status transition: % -> Cancelled. Only Delivery In Progress -> Cancelled is allowed.',

            v_old_status;

    END IF;

END IF;





        ------------------------------------------------------------------

        -- TERMINAL STATES

        ------------------------------------------------------------------



        -- Delivered ΓåÆ immutable

        IF v_old_status = 'Delivered'

           AND v_new_status <> 'Delivered'

        THEN

            RAISE EXCEPTION

                'Γ¥î Delivered usage cannot change status.';

        END IF;



        -- Rejected ΓåÆ immutable

        IF v_old_status = 'Rejected'

           AND v_new_status <> 'Rejected'

        THEN

            RAISE EXCEPTION

                'Γ¥î Rejected usage cannot change status.';

        END IF;



        -- Cancelled ΓåÆ immutable

        IF v_old_status = 'Cancelled'

           AND v_new_status <> 'Cancelled'

        THEN

            RAISE EXCEPTION

                'Γ¥î Cancelled usage cannot change status.';

        END IF;



        ------------------------------------------------------------------

        -- COMMERCIAL APPROVAL PENDING

        ------------------------------------------------------------------

        IF v_old_status = 'Commercial Approval Pending'

           AND v_new_status NOT IN (

                'Delivery In Progress',

                'Rejected'

           )

        THEN

            RAISE EXCEPTION

                'Γ¥î Invalid transition from Commercial Approval Pending to %.',

                v_new_status;

        END IF;



        ------------------------------------------------------------------

        -- IN PROGRESS

        ------------------------------------------------------------------

        IF v_old_status = 'Delivery In Progress'

           AND v_new_status NOT IN (

                'Pending Sign-Off',

                'Cancelled',

                'Delivery In Progress'

           )

        THEN

            RAISE EXCEPTION

                'Γ¥î Invalid transition from In Progress to %.',

                v_new_status;

        END IF;



        ------------------------------------------------------------------

        -- PENDING SIGN-OFF

        ------------------------------------------------------------------

        IF v_old_status = 'Pending Sign-Off'

           AND v_new_status NOT IN (

                'Delivered',

                'Delivery In Progress'

           )

        THEN

            RAISE EXCEPTION

                'Γ¥î Invalid transition from Pending Sign-Off to %.',

                v_new_status;

        END IF;



    END IF;





    ------------------------------------------------------------------

    -- Normalize persisted value

    ------------------------------------------------------------------

    NEW.status := v_new_status;



    RETURN NEW;



END;$function$