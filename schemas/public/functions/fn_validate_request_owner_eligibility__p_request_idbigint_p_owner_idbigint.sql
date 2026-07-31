CREATE OR REPLACE FUNCTION public.fn_validate_request_owner_eligibility(p_request_id bigint, p_owner_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_module text;

    v_count_eligible int;

BEGIN

    ------------------------------------------------------------------

    -- 1) Request must exist + load module

    ------------------------------------------------------------------

    SELECT module

    INTO v_module

    FROM public.requests

    WHERE in_record_id = p_request_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Γ¥î Invalid request ID % for handover',

            p_request_id;

    END IF;



    ------------------------------------------------------------------

    -- 2) Owner must exist

    ------------------------------------------------------------------

    PERFORM 1

    FROM public.users

    WHERE in_record_id = p_owner_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Γ¥î Invalid new owner (ID: %) ΓÇö user does not exist',

            p_owner_id;

    END IF;



    ------------------------------------------------------------------

    -- 3) Services module eligibility check (NON-SKU forced affinity)

    ------------------------------------------------------------------

    IF v_module = 'Services' THEN



        -- Run only if SKUs exist for this request

        IF EXISTS (

            SELECT 1

            FROM public.requests_services

            WHERE ref_requests_record_id = p_request_id

        ) THEN

            SELECT COUNT(*)

            INTO v_count_eligible

            FROM public.requests_services rs

            JOIN public.services_sku_onboarding ps

              ON ps.ref_services_sku = rs.ref_services_sku

             AND ps.sarthi_name     = p_owner_id

            WHERE rs.ref_requests_record_id = p_request_id

              AND ps.status IN ('Active','Dormant')

              AND ps.competence_level IN (

                    'Apprentice',

                    'Practioner',

                    'Professional'

              );



            IF v_count_eligible = 0 THEN

                RAISE EXCEPTION

                    'Γ¥î User % is not eligible to own Services request %',

                    p_owner_id, p_request_id;

            END IF;

        END IF;

    END IF;

END;

$function$