CREATE OR REPLACE FUNCTION public.fn_check_forced_affinity_at_commit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$



DECLARE



    v_request_id bigint;

    v_module text;



BEGIN



    ------------------------------------------------------------------

    -- Resolve Request

    ------------------------------------------------------------------

    v_request_id :=

        COALESCE(

            NEW.in_record_id,

            OLD.in_record_id

        );



    ------------------------------------------------------------------

    -- Resolve Module

    ------------------------------------------------------------------

    SELECT r.module

    INTO v_module

    FROM public.requests r

    WHERE r.in_record_id = v_request_id;



    IF v_module IS NULL THEN

        RETURN NULL;

    END IF;



    ------------------------------------------------------------------

    -- SERVICES MODULE

    ------------------------------------------------------------------

    IF initcap(lower(trim(v_module))) = 'Services' THEN



        IF EXISTS (



            SELECT 1

            FROM public.requests r



            JOIN public.requests_services rs

              ON rs.ref_requests_record_id =

                 r.in_record_id



            JOIN public.services_sku s

              ON s.in_record_id =

                 rs.ref_services_sku



            WHERE r.in_record_id =

                  v_request_id



              AND s.forced_affinity = 'Yes'



              AND r.owner IS NULL



        )

        THEN

            RAISE EXCEPTION

                'Forced-affinity SKU(s) on Services request % require an owner before commit.',

                v_request_id;

        END IF;



    END IF;



------------------------------------------------------------------

-- ROLES MODULE

------------------------------------------------------------------

IF initcap(lower(trim(v_module))) = 'Roles' THEN



    IF EXISTS (



        SELECT 1

        FROM public.requests r



        JOIN public.requests_sku_roles rsr

          ON rsr.ref_requests_in_record_id =

             r.in_record_id



        JOIN public.services_sku_roles ssr

          ON ssr.in_record_id =

             rsr.ref_services_sku_roles_in_record_id



        WHERE r.in_record_id =

              v_request_id



          AND ssr.affinity = 'Yes'



          AND r.owner IS NULL



    )

    THEN

        RAISE EXCEPTION

            'Forced-affinity Role SKU(s) on request % require a role owner before commit.',

            v_request_id;

    END IF;



END IF;



    RETURN NULL;



END;

$function$