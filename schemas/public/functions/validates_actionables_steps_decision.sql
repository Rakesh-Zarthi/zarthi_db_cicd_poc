CREATE OR REPLACE FUNCTION public.validates_actionables_steps_decision()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_actionable_category text;

    v_actionable_name     text;

    v_module              text;

    v_bypass              BOOLEAN := FALSE;

    v_step2_decision      text;

BEGIN

    ------------------------------------------------------------------

    -- 0) Guard: actionable reference must exist

    ------------------------------------------------------------------

    IF NEW.ref_actionables_in_record_id IS NULL THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 1) Resolve actionable + request context

    ------------------------------------------------------------------

    SELECT

        initcap(lower(a.actionable_category)),

        initcap(lower(a.actionable_name)),

        initcap(lower(r.module))

    INTO

        v_actionable_category,

        v_actionable_name,

        v_module

    FROM public.actionables a

    JOIN public.requests r

      ON r.in_record_id = a.request_subject

    WHERE a.in_record_id = NEW.ref_actionables_in_record_id;



    IF NOT FOUND THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 2) Apply ONLY for Billing ΓåÆ Sign Off

    ------------------------------------------------------------------

    IF NOT (

        v_actionable_category = 'Billing'

        AND v_actionable_name = 'Sign Off'

    ) THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 3) delivery_decision allowed ONLY on Step-2 / Step-3

    ------------------------------------------------------------------

    IF NEW.delivery_decision IS NOT NULL

       AND NEW.step_no NOT IN (2, 3) THEN

        RAISE EXCEPTION

            'delivery_decision allowed only on Step-2 or Step-3 for Billing ΓåÆ Sign Off'

            USING ERRCODE = '23514';

    END IF;



    ------------------------------------------------------------------

    -- 4) delivery_decision ΓçÆ step must be Complete

    ------------------------------------------------------------------

    IF NEW.delivery_decision IS NOT NULL

       AND NEW.status <> 'Complete' THEN

        RAISE EXCEPTION

            'delivery_decision can only be set when step is Complete for Billing ΓåÆ Sign Off'

            USING ERRCODE = '23514';

    END IF;



    ------------------------------------------------------------------

    -- 5) Step-2 / Step-3 MUST provide delivery_decision when Complete

    ------------------------------------------------------------------

    IF NEW.step_no IN (2, 3)

       AND NEW.status = 'Complete'

       AND NEW.delivery_decision IS NULL THEN

        RAISE EXCEPTION

            'Step-% must provide delivery_decision for Billing ΓåÆ Sign Off',

            NEW.step_no

            USING ERRCODE = '23514';

    END IF;



    ------------------------------------------------------------------

    -- 6) Staffing-only enforcement

    ------------------------------------------------------------------

    IF v_module = 'Staffing'

       AND NEW.status = 'Complete'

       AND NEW.step_no IN (2, 3) THEN



        ------------------------------------------------------------------

        -- STEP-3: fetch Step-2 decision

        ------------------------------------------------------------------

        IF NEW.step_no = 3 THEN

            SELECT delivery_decision

              INTO v_step2_decision

              FROM public.actionables_steps

             WHERE ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

               AND step_no = 2;



            IF NOT FOUND THEN

                RAISE EXCEPTION

                    'Step-2 must exist and be completed before completing Step-3 for Billing ΓåÆ Sign Off'

                    USING ERRCODE = '23514';

            END IF;

        END IF;



        ------------------------------------------------------------------

        -- STEP-3 consistency: Delivered ΓçÆ Step-2 Delivered

        ------------------------------------------------------------------

        IF NEW.step_no = 3

           AND NEW.delivery_decision = 'Delivered'

           AND v_step2_decision <> 'Delivered' THEN

            RAISE EXCEPTION

                'Step-3 Delivered requires Step-2 delivery_decision = Delivered'

                USING ERRCODE = '23514';

        END IF;



        ------------------------------------------------------------------

        -- Timesheet enforcement (ACTIONABLE scoped)

        ------------------------------------------------------------------

        IF NEW.delivery_decision = 'Delivered' THEN

            IF EXISTS (

                SELECT 1

                FROM public.timesheet t

                WHERE t.ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

                  AND t.status IS DISTINCT FROM 'Approve'

            ) THEN

                RAISE EXCEPTION

                    'All timesheets must be Approved when delivery_decision = Delivered'

                    USING ERRCODE = '23514';

            END IF;

        END IF;



        IF NEW.delivery_decision = 'Not Delivered' THEN

            IF EXISTS (

                SELECT 1

                FROM public.timesheet t

                WHERE t.ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

                  AND t.status IS DISTINCT FROM 'Open'

            ) THEN

                RAISE EXCEPTION

                    'All timesheets must be Open when delivery_decision = Not Delivered'

                    USING ERRCODE = '23514';

            END IF;

        END IF;



    END IF;



IF v_module = 'Roles' THEN



    PERFORM public.validates_actionables_steps_decision_roles(NEW);



END IF;



    RETURN NEW;

END;

$function$