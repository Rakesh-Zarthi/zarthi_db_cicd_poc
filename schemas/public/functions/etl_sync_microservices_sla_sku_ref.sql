CREATE OR REPLACE FUNCTION public.etl_sync_microservices_sla_sku_ref()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- =====================

    -- INSERT HANDLING

    -- =====================

    IF TG_OP = 'INSERT' THEN

        -- Prefer ref_services_sku as source

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



    -- Case 1: ref_services_sku changed ΓåÆ sync mirror

    IF NEW.ref_services_sku IS DISTINCT FROM OLD.ref_services_sku THEN

        IF NEW.ref_services_sku_in_record_id IS DISTINCT FROM NEW.ref_services_sku THEN

            NEW.ref_services_sku_in_record_id := NEW.ref_services_sku;

        END IF;

    END IF;



    -- Case 2: mirror changed ΓåÆ sync back

    IF NEW.ref_services_sku_in_record_id IS DISTINCT FROM OLD.ref_services_sku_in_record_id THEN

        IF NEW.ref_services_sku IS DISTINCT FROM NEW.ref_services_sku_in_record_id THEN

            NEW.ref_services_sku := NEW.ref_services_sku_in_record_id;

        END IF;

    END IF;



    RETURN NEW;

END;

$function$