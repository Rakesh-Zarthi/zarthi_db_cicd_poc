CREATE OR REPLACE FUNCTION public.etl_sync_services_sku_onboarding_refs()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- =====================

    -- INSERT HANDLING

    -- =====================

    IF TG_OP = 'INSERT' THEN

        -- Users sync

        IF NEW.sarthi_name IS NOT NULL THEN

            NEW.ref_users_in_record_id := NEW.sarthi_name;

        ELSIF NEW.ref_users_in_record_id IS NOT NULL THEN

            NEW.sarthi_name := NEW.ref_users_in_record_id;

        END IF;



        -- SKU sync

        IF NEW.ref_services_sku IS NOT NULL THEN

            NEW.ref_services_sku_in_record_id := NEW.ref_services_sku;

        ELSIF NEW.ref_services_sku_in_record_id IS NOT NULL THEN

            NEW.ref_services_sku := NEW.ref_services_sku_in_record_id;

        END IF;



        RETURN NEW;

    END IF;



    -- =====================

    -- UPDATE HANDLING

    -- =====================



    -- ---- Users Sync ----

    IF NEW.sarthi_name IS DISTINCT FROM OLD.sarthi_name THEN

        IF NEW.ref_users_in_record_id IS DISTINCT FROM NEW.sarthi_name THEN

            NEW.ref_users_in_record_id := NEW.sarthi_name;

        END IF;

    END IF;



    IF NEW.ref_users_in_record_id IS DISTINCT FROM OLD.ref_users_in_record_id THEN

        IF NEW.sarthi_name IS DISTINCT FROM NEW.ref_users_in_record_id THEN

            NEW.sarthi_name := NEW.ref_users_in_record_id;

        END IF;

    END IF;



    -- ---- SKU Sync ----

    IF NEW.ref_services_sku IS DISTINCT FROM OLD.ref_services_sku THEN

        IF NEW.ref_services_sku_in_record_id IS DISTINCT FROM NEW.ref_services_sku THEN

            NEW.ref_services_sku_in_record_id := NEW.ref_services_sku;

        END IF;

    END IF;



    IF NEW.ref_services_sku_in_record_id IS DISTINCT FROM OLD.ref_services_sku_in_record_id THEN

        IF NEW.ref_services_sku IS DISTINCT FROM NEW.ref_services_sku_in_record_id THEN

            NEW.ref_services_sku := NEW.ref_services_sku_in_record_id;

        END IF;

    END IF;



    RETURN NEW;

END;

$function$