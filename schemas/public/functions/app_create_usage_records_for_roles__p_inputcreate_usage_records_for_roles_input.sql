CREATE OR REPLACE FUNCTION public.app_create_usage_records_for_roles(p_input create_usage_records_for_roles_input)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$



DECLARE

    v_request_module text;



BEGIN



    ------------------------------------------------------------------

    -- Validate request exists

    ------------------------------------------------------------------

    SELECT r.module

    INTO v_request_module

    FROM public.requests r

    WHERE r.in_record_id = p_input.ref_requests_in_record_id;



    IF v_request_module IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE_RECORDS][REQUEST_VALIDATE][ERROR] request_id=% reason=NOT_FOUND',

            p_input.ref_requests_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- Allow only Roles module

    ------------------------------------------------------------------

    IF v_request_module <> 'Roles' THEN

        RAISE EXCEPTION

            '[CREATE_USAGE_RECORDS][REQUEST_VALIDATE][ERROR] request_id=% module=% reason=INVALID_MODULE',

            p_input.ref_requests_in_record_id,

            v_request_module;

    END IF;



 ------------------------------------------------------------------

-- Quantity Validation

------------------------------------------------------------------

IF p_input.quantity IS NULL

   OR p_input.quantity <= 0

THEN

    RAISE EXCEPTION

        '[CREATE_USAGE_RECORDS][QUANTITY_VALIDATE][ERROR] quantity=% reason=INVALID_QUANTITY',

        p_input.quantity;

END IF;



-- Microservice quantity must be whole number

IF p_input.ref_services_sku_in_record_id IS NOT NULL

   AND p_input.quantity <> FLOOR(p_input.quantity)

THEN

    RAISE EXCEPTION

        '[CREATE_USAGE_RECORDS][QUANTITY_VALIDATE][ERROR] quantity=% reason=INVALID_QUANTITY',

        p_input.quantity;

END IF;



   IF p_input.ref_services_sku_in_record_id IS NOT NULL THEN



    ------------------------------------------------------------------

    -- Microservice

    ------------------------------------------------------------------

    INSERT INTO public.usage

    (

        ref_requests_in_record_id,

        unit_price,

        quantity,

        status,

        ref_actionables_in_record_immediate_consumer,

        ref_users_in_record_id_consumer,

        ref_users_in_record_id_customer,

        ref_users_in_record_id_owner,

        ref_services_sku_in_record_id,

        task

    )

    SELECT

        p_input.ref_requests_in_record_id,

        p_input.unit_price,

        1,

        p_input.status,

        p_input.ref_actionables_in_record_immediate_consumer,

        p_input.ref_users_in_record_id_consumer,

        p_input.ref_users_in_record_id_customer,

        p_input.ref_users_in_record_id_owner,

        p_input.ref_services_sku_in_record_id,

        NULL

    FROM generate_series(1, p_input.quantity::integer);



ELSE



    ------------------------------------------------------------------

    -- Hours

    ------------------------------------------------------------------



    -- Full hours

    INSERT INTO public.usage

    (

        ref_requests_in_record_id,

        unit_price,

        quantity,

        status,

        ref_actionables_in_record_immediate_consumer,

        ref_users_in_record_id_consumer,

        ref_users_in_record_id_customer,

        ref_users_in_record_id_owner,

        ref_services_sku_in_record_id,

        task

    )

    SELECT

        p_input.ref_requests_in_record_id,

        p_input.unit_price,

        1,

        p_input.status,

        p_input.ref_actionables_in_record_immediate_consumer,

        p_input.ref_users_in_record_id_consumer,

        p_input.ref_users_in_record_id_customer,

        p_input.ref_users_in_record_id_owner,

        NULL,

        p_input.task

    FROM generate_series(1, floor(p_input.quantity)::integer);



    -- Fractional hour

    IF p_input.quantity - floor(p_input.quantity) > 0 THEN



        INSERT INTO public.usage

        (

            ref_requests_in_record_id,

            unit_price,

            quantity,

            status,

            ref_actionables_in_record_immediate_consumer,

            ref_users_in_record_id_consumer,

            ref_users_in_record_id_customer,

            ref_users_in_record_id_owner,

            ref_services_sku_in_record_id,

            task

        )

        VALUES

        (

            p_input.ref_requests_in_record_id,

            p_input.unit_price,

            p_input.quantity - floor(p_input.quantity),

            p_input.status,

            p_input.ref_actionables_in_record_immediate_consumer,

            p_input.ref_users_in_record_id_consumer,

            p_input.ref_users_in_record_id_customer,

            p_input.ref_users_in_record_id_owner,

            NULL,

            p_input.task

        );



    END IF;



END IF;

    ------------------------------------------------------------------

    -- Success

    ------------------------------------------------------------------

    RETURN TRUE;





END;$function$