CREATE OR REPLACE FUNCTION public.trg_validate_services_per_request_usage()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_module text;

BEGIN



    ----------------------------------------------------------

    -- Only validate Booked / Delivered

    ----------------------------------------------------------

    IF NEW.status NOT IN ('Booked', 'Delivered') THEN

        RETURN NEW;

    END IF;



    ----------------------------------------------------------

    -- Only validate Per Request

    ----------------------------------------------------------

    IF NEW.quantity_unit <> 'Per Request' THEN

        RETURN NEW;

    END IF;



    ----------------------------------------------------------

    -- Resolve Request Module

    ----------------------------------------------------------

    SELECT r.module

    INTO v_module

    FROM public.requests r

    WHERE r.in_record_id = NEW.ref_requests_in_record_id;



    ----------------------------------------------------------

    -- Only Services Module

    ----------------------------------------------------------

    IF v_module <> 'Services' THEN

        RETURN NEW;

    END IF;



    ----------------------------------------------------------

    -- Prevent Duplicate Delivered/Booked

    ----------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.usage u

        WHERE u.ref_requests_in_record_id =

              NEW.ref_requests_in_record_id

          AND u.status IN ('Booked', 'Delivered')

          AND u.quantity_unit = 'Per Request'

          AND u.in_record_id <> COALESCE(NEW.in_record_id, -1)

    ) THEN



        RAISE EXCEPTION

            'Only one Per Request Booked/Delivered usage record is allowed for Services request %',

            NEW.ref_requests_in_record_id;



    END IF;



    RETURN NEW;

END;

$function$