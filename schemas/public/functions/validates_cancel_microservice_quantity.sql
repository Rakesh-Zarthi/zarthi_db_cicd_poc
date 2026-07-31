CREATE OR REPLACE FUNCTION public.validates_cancel_microservice_quantity()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$



DECLARE



    ------------------------------------------------------------------

    -- Actionable

    ------------------------------------------------------------------

    v_actionable_name      text;

    v_actionable_category  text;

    v_request_id           bigint;

    v_module               text;



    ------------------------------------------------------------------

    -- Cancellation Metadata

    ------------------------------------------------------------------

    v_ms_id               bigint;

    v_quantity            bigint;



    ------------------------------------------------------------------

    -- Validation

    ------------------------------------------------------------------

    v_in_progress_qty     bigint;



BEGIN



    ------------------------------------------------------------------

    -- Only validate on Complete

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

        r.in_record_id,

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

        RAISE EXCEPTION

            'Invalid actionable reference.';

    END IF;



    ------------------------------------------------------------------

    -- Only apply for Roles

    ------------------------------------------------------------------

    IF v_module <> 'Roles' THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Only apply for Orders cancellation actionables

    ------------------------------------------------------------------

    IF NOT (

        v_actionable_category = 'Orders'

        AND

        v_actionable_name IN (

            'Cancel Microservice Quantity',

            'Cancel Microservice Quantity (Bulk)'

        )

    )

    THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Resolve Step 1 Metadata

    ------------------------------------------------------------------

SELECT

    COALESCE(

        (ast.step_metadata -> 'metadata' ->> 'msId')::bigint,

        (ast.step_metadata -> 'draftedData' ->> 'msId')::bigint

    ),

    COALESCE(

        (ast.step_metadata -> 'metadata' ->> 'quantity')::bigint,

        (ast.step_metadata -> 'draftedData' ->> 'quantity')::bigint

    )

INTO

        v_ms_id,

        v_quantity

    FROM public.actionables_steps ast

    WHERE ast.ref_actionables_in_record_id =

          NEW.ref_actionables_in_record_id

      AND ast.step_no = 1;



    ------------------------------------------------------------------

    -- Validate Metadata

    ------------------------------------------------------------------

    IF v_ms_id IS NULL THEN

        RAISE EXCEPTION

            'Microservice SKU is mandatory for cancellation.';

    END IF;



    IF v_quantity IS NULL

       OR v_quantity <= 0

    THEN

        RAISE EXCEPTION

            'Cancel quantity must be greater than 0.';

    END IF;



    ------------------------------------------------------------------

    -- Validate Latest Cancellable Quantity

    ------------------------------------------------------------------

    SELECT COUNT(*)

    INTO v_in_progress_qty

    FROM (



        SELECT u.in_record_id

        FROM public.usage u

        WHERE u.ref_requests_in_record_id = v_request_id

          AND u.ref_services_sku_in_record_id = v_ms_id

          AND u.status = 'Delivery In Progress'

        ORDER BY

            u.in_added_time DESC,

            u.in_record_id DESC

        LIMIT v_quantity



    ) x;



    ------------------------------------------------------------------

    -- Validate Requested Quantity

    ------------------------------------------------------------------

    IF v_in_progress_qty < v_quantity THEN

        RAISE EXCEPTION

            'Latest cancellable In Progress quantity (%) is less than requested cancel quantity (%) for SKU %.',

            v_in_progress_qty,

            v_quantity,

            v_ms_id;

    END IF;



    RETURN NEW;



END;

$function$