CREATE OR REPLACE FUNCTION public.trg_usage_auto_fill_sku_details()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$



DECLARE

    v_request_module text;



BEGIN



    ------------------------------------------------------------------

    -- Validate request module

    ------------------------------------------------------------------

    SELECT r.module

    INTO v_request_module

    FROM public.requests r

    WHERE r.in_record_id =

          NEW.ref_requests_in_record_id;



    IF v_request_module IS NULL THEN

        RAISE EXCEPTION

            'Invalid request id %',

            NEW.ref_requests_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- Only Roles module allowed

    ------------------------------------------------------------------

    IF v_request_module <> 'Roles' THEN

        RETURN NEW;

    END IF;



------------------------------------------------------------------

-- Task-based Usage

------------------------------------------------------------------

IF NEW.ref_services_sku_in_record_id IS NULL THEN



    IF COALESCE(TRIM(NEW.task), '') = '' THEN

        RAISE EXCEPTION

            'Either ref_services_sku_in_record_id or task must be provided.';

    END IF;



    NEW.quantity_unit := 'Per Hour';

    NEW.micro_pricing_unit := 'Per Hour';



    RETURN NEW;



END IF;



    ------------------------------------------------------------------

    -- SKU-based Usage

    ------------------------------------------------------------------

    SELECT

        ss.quantity_unit,

        ss.microservice_pricing_unit

    INTO

        NEW.quantity_unit,

        NEW.micro_pricing_unit

    FROM public.services_sku ss

    WHERE ss.in_record_id =

          NEW.ref_services_sku_in_record_id;



    ------------------------------------------------------------------

    -- Validate SKU exists

    ------------------------------------------------------------------

    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid services_sku id %',

            NEW.ref_services_sku_in_record_id;

    END IF;



    RETURN NEW;



END;$function$