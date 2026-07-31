CREATE OR REPLACE FUNCTION public.tg_validate_service_owner_eligibility()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_owner bigint;

    v_cnt   int;

BEGIN

    SELECT owner

    INTO v_owner

    FROM requests

    WHERE in_record_id = NEW.ref_requests_record_id;



    IF v_owner IS NULL THEN

        RETURN NEW;

    END IF;



    SELECT COUNT(*)

    INTO v_cnt

    FROM services_sku_onboarding ps

    WHERE ps.ref_services_sku = NEW.ref_services_sku

      AND ps.sarthi_name     = v_owner

      AND ps.status IN ('Active','Dormant')

      AND ps.competence_level IN

          ('Apprentice','Practioner','Professional');



    IF v_cnt = 0 THEN

        RAISE EXCEPTION

            'Γ¥î Owner % lacks eligibility for service SKU %',

            v_owner, NEW.ref_services_sku;

    END IF;



    RETURN NEW;

END;

$function$