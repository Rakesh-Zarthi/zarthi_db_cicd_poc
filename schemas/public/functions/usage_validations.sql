CREATE OR REPLACE FUNCTION public.usage_validations()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_json               jsonb;



    v_request_id         bigint;

    v_req_module         text;



    v_expected_qty_unit  text;

    v_qty_unit           text;



    v_status_new         text;



    v_unit_price         numeric;

    v_timesheet_hours    numeric;



    v_actionable         record;



BEGIN



    ------------------------------------------------------------------

    -- 1. Mandatory guards

    ------------------------------------------------------------------

    IF NEW.ref_requests_in_record_id IS NULL THEN

        RAISE EXCEPTION

            'ref_requests_in_record_id is mandatory.';

    END IF;



    IF NEW.ref_actionables_in_record_immediate_consumer IS NULL THEN

        RAISE EXCEPTION

            'ref_actionables_in_record_immediate_consumer is mandatory.';

    END IF;



    IF NEW.status IS NULL THEN

        RAISE EXCEPTION

            'status is mandatory.';

    END IF;



    IF NEW.quantity_unit IS NULL THEN

        RAISE EXCEPTION

            'quantity_unit is mandatory.';

    END IF;



    ------------------------------------------------------------------

    -- 2. Normalize

    ------------------------------------------------------------------

    v_status_new :=

        initcap(lower(trim(NEW.status::text)));



    v_qty_unit :=

        initcap(lower(trim(NEW.quantity_unit::text)));



    v_unit_price :=

        COALESCE(NEW.unit_price::numeric, 0);



    ------------------------------------------------------------------

    -- 3. Resolve request + module

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

    -- Allowed modules

    ------------------------------------------------------------------

    IF v_req_module NOT IN (

        'Services',

        'Staffing',

        'Roles'

    )

    THEN

        RAISE EXCEPTION

            'Usage allowed only for Services, Staffing or Roles.';

    END IF;



    v_request_id := NEW.ref_requests_in_record_id;



    ------------------------------------------------------------------

    -- 4. Validate actionable

    ------------------------------------------------------------------

    SELECT *

    INTO v_actionable

    FROM public.actionables

    WHERE in_record_id =

          NEW.ref_actionables_in_record_immediate_consumer;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid actionable reference.';

    END IF;



    ------------------------------------------------------------------

    -- Request ownership validation

    ------------------------------------------------------------------

    IF v_actionable.request_subject <> v_request_id THEN

        RAISE EXCEPTION

            'Usage and actionable must belong to same request.';

    END IF;



    ------------------------------------------------------------------

    -- Allowed usage-origin actionables

    ------------------------------------------------------------------

    IF NOT (



        ------------------------------------------------------------------

        -- Billing ΓåÆ Sign Off

        ------------------------------------------------------------------

        (

            initcap(lower(trim(v_actionable.actionable_category)))

                = 'Billing'



            AND



            initcap(lower(trim(v_actionable.actionable_name)))

                = 'Sign Off'

        )



        OR



        ------------------------------------------------------------------

        -- Orders ΓåÆ Add Microservice Quantity

        ------------------------------------------------------------------

        (

            initcap(lower(trim(v_actionable.actionable_category)))

                = 'Orders'



            AND



            initcap(lower(trim(v_actionable.actionable_name)))

                IN (

                    'Add Microservice Quantity',

                    'Add Microservice Quantity (Bulk)',

					'Add Orders'

                )

        )



    )

    THEN

        RAISE EXCEPTION

            'Usage can only originate from Billing ΓåÆ Sign Off or Orders ΓåÆ Add Microservice Quantity actionables.';

    END IF;



    ------------------------------------------------------------------

    -- 5. Load workflow metadata

    ------------------------------------------------------------------

    SELECT actionable_config

    INTO v_json

    FROM public.actionables_execution_metadata

    ORDER BY in_record_id DESC

    LIMIT 1;



    IF v_json IS NULL THEN

        RAISE EXCEPTION

            'Workflow metadata not configured.';

    END IF;



    ------------------------------------------------------------------

    -- 6. Resolve authoritative quantity unit

    ------------------------------------------------------------------

------------------------------------------------------------------

-- Services

------------------------------------------------------------------

IF v_req_module = 'Services' THEN



    SELECT

        initcap(lower(trim(sku.quantity_unit)))

    INTO v_expected_qty_unit

    FROM public.requests_services rs

    JOIN public.services_sku sku

         ON rs.ref_services_sku = sku.in_record_id

    WHERE rs.ref_requests_record_id = v_request_id

    LIMIT 1;



------------------------------------------------------------------

-- Roles

------------------------------------------------------------------

ELSIF v_req_module = 'Roles' THEN



    ------------------------------------------------------------------

    -- Task-based Usage

    ------------------------------------------------------------------

    IF NEW.task IS NOT NULL THEN



        v_expected_qty_unit := 'Per Hour';



------------------------------------------------------------------
-- SKU-based Usage
------------------------------------------------------------------
ELSE

    SELECT
        initcap(lower(trim(ss.quantity_unit)))
    INTO v_expected_qty_unit
    FROM public.services_sku ss
    WHERE ss.in_record_id = NEW.ref_services_sku_in_record_id;

    IF v_expected_qty_unit IS NULL THEN
        RAISE EXCEPTION
            'Quantity unit not found for SKU %.',
            NEW.ref_services_sku_in_record_id;
    END IF;

END IF;

------------------------------------------------------------------

-- Staffing

------------------------------------------------------------------

ELSIF v_req_module = 'Staffing' THEN



    v_expected_qty_unit :=

        initcap(lower(trim(

            v_json -> 'Request'

                   -> 'Sub Request Type'

                   -> 'Staffing'

                   ->> 'Quantity Unit'

        )));



END IF;





    IF v_expected_qty_unit IS NULL THEN

        RAISE EXCEPTION

            'Quantity Unit not configured for request %.',

            v_request_id;

    END IF;



    ------------------------------------------------------------------

    -- 7. Enforce quantity unit

    ------------------------------------------------------------------

    IF v_qty_unit <> v_expected_qty_unit THEN

        RAISE EXCEPTION

            'quantity_unit must be "%", got "%".',

            v_expected_qty_unit,

            v_qty_unit;

    END IF;



    ------------------------------------------------------------------

    -- 8. INSERT lifecycle validation

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        ------------------------------------------------------------------

        -- Services + Staffing

        ------------------------------------------------------------------

        IF v_req_module IN ('Services', 'Staffing')

           AND v_status_new <> 'Awaiting Approval'

        THEN

            RAISE EXCEPTION

                'Usage must start in Awaiting Approval status.';

        END IF;



        ------------------------------------------------------------------

        -- Roles

        ------------------------------------------------------------------

        IF v_req_module = 'Roles'

           AND v_status_new <> 'Commercial Approval Pending'

        THEN

            RAISE EXCEPTION

                'Roles usage must start in Commercial Approval Pending.';

        END IF;



    END IF;



    ------------------------------------------------------------------

    -- 9A. Quantity resolution

    ------------------------------------------------------------------

    IF v_qty_unit = 'Per Request' THEN

        NEW.quantity := 1;

    END IF;



    ------------------------------------------------------------------

    -- 9B. Per Hour logic

    ------------------------------------------------------------------

    IF v_qty_unit = 'Per Hour' THEN



        ------------------------------------------------------------------

        -- Awaiting Approval

        ------------------------------------------------------------------

        IF v_status_new = 'Awaiting Approval' THEN

            NEW.quantity :=

                COALESCE(NEW.quantity, 0);

        END IF;



        ------------------------------------------------------------------

        -- Approved / Billed

        ------------------------------------------------------------------

        IF v_status_new IN ('Approved', 'Billed') THEN



            SELECT

                SUM(

                    EXTRACT(

                        epoch FROM (

                            (

                                (t.to_date_time).date_part

                                +

                                (t.to_date_time).time_part

                            )

                            -

                            (

                                (t.from_date_time).date_part

                                +

                                (t.from_date_time).time_part

                            )

                        )

                    ) / 3600

                )

            INTO v_timesheet_hours

            FROM public.timesheet t

            WHERE t.ref_usage_in_record_id =

                  NEW.in_record_id

              AND t.status = 'Approve';



            IF v_timesheet_hours IS NULL

               OR v_timesheet_hours <= 0

            THEN

                RAISE EXCEPTION

                    'Approved timesheets must be linked before approving usage.';

            END IF;



            NEW.quantity := v_timesheet_hours;



        END IF;



    END IF;



    ------------------------------------------------------------------

    -- 10. Pricing validation

    ------------------------------------------------------------------

    IF v_unit_price < 0 THEN

        RAISE EXCEPTION

            'unit_price must be > 0.';

    END IF;



    ------------------------------------------------------------------

    -- Normalize persisted values

    ------------------------------------------------------------------

    NEW.status := v_status_new;

    NEW.quantity_unit := v_qty_unit;



    RETURN NEW;



END;$function$