CREATE OR REPLACE FUNCTION public.tg_validate_services_owner_eligibility()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_owner bigint;

    v_ok int;

BEGIN

    -- Resolve owner from requests

    SELECT r.owner

    INTO v_owner

    FROM public.requests r

    WHERE r.in_record_id = NEW.ref_requests_record_id;



    -- Owner may be NULL during construction

    IF v_owner IS NULL THEN

        RETURN NEW;

    END IF;



    SELECT COUNT(*)

    INTO v_ok

    FROM public.services_sku_onboarding s

    WHERE s.ref_services_sku = NEW.ref_services_sku

      AND s.sarthi_name = v_owner

      AND s.status IN ('Active','Dormant')

      AND s.competence_level IN ('Apprentice','Practioner','Professional');



    IF v_ok = 0 THEN

        RAISE EXCEPTION

            'Γ¥î Owner % is NOT eligible for Service SKU %',

            v_owner, NEW.ref_services_sku;

    END IF;



    RETURN NEW;

END;

$function$