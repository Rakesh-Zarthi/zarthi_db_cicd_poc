CREATE OR REPLACE FUNCTION public.trg_validate_usage_role_sku_mapping()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_req_module text;

BEGIN


    IF TG_OP = 'UPDATE' THEN

        -- If neither Request nor SKU changed, skip validation
        IF NEW.ref_requests_in_record_id IS NOT DISTINCT FROM OLD.ref_requests_in_record_id
           AND NEW.ref_services_sku_in_record_id IS NOT DISTINCT FROM OLD.ref_services_sku_in_record_id
        THEN
            RETURN NEW;
        END IF;

    END IF;

    ------------------------------------------------------------------

    -- Resolve request module

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

    -- Skip validation for Services / Staffing

    ------------------------------------------------------------------

    IF v_req_module IN ('Services', 'Staffing') THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Roles module validations

    ------------------------------------------------------------------

    IF v_req_module = 'Roles' THEN



        ------------------------------------------------------------------

        -- SKU is mandatory only when Task is NULL

        ------------------------------------------------------------------

        IF NEW.task IS NULL

           AND NEW.ref_services_sku_in_record_id IS NULL THEN

            RAISE EXCEPTION

                'SKU is mandatory for Roles requests when Task is not provided.';

        END IF;



        ------------------------------------------------------------------

        -- If SKU is provided, validate it is tagged under the role request

        ------------------------------------------------------------------

        IF NEW.ref_services_sku_in_record_id IS NOT NULL THEN



            IF NOT EXISTS (



                SELECT 1

                FROM public.requests r



                JOIN public.requests_sku_roles rsr

                     ON r.in_record_id =

                        rsr.ref_requests_in_record_id



                JOIN public.services_sku_roles ssr

                     ON rsr.ref_services_sku_roles_in_record_id =

                        ssr.in_record_id



                JOIN public.services_sku ss

                     ON ssr.in_record_id =

                        ss.ref_services_sku_roles_in_record_id



                WHERE r.in_record_id =

                      NEW.ref_requests_in_record_id



                  AND ss.in_record_id =

                      NEW.ref_services_sku_in_record_id



            )

            THEN

                RAISE EXCEPTION

                    'SKU % is not tagged under the role associated with request %.',

                    NEW.ref_services_sku_in_record_id,

                    NEW.ref_requests_in_record_id;

            END IF;



        END IF;



    END IF;



    RETURN NEW;



END;$function$