CREATE OR REPLACE FUNCTION public.game_get_random_practices(p_limit integer)
 RETURNS SETOF practices_view_event
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_total int;

    v_limit int;

BEGIN

    -- Invalid input

    IF p_limit <= 0 THEN

        RETURN;

    END IF;



    -- Count eligible rows

    SELECT COUNT(*)

    INTO v_total

    FROM public.practices_view_event pve

    WHERE pve.gen_has_minimum_microservices = true

      AND EXISTS (

          SELECT 1

          FROM services_sku s

          WHERE s.ref_practice_id = pve.in_record_id

            AND s.microservice_status = 'Developed'

      );



    -- No data

    IF v_total = 0 THEN

        RETURN;

    END IF;



    -- Adjust limit

    v_limit := LEAST(p_limit, v_total);



    -- Return random rows

    RETURN QUERY

    SELECT *

    FROM public.practices_view_event pve

    WHERE pve.gen_has_minimum_microservices = true

      AND EXISTS (

          SELECT 1

          FROM services_sku s

          WHERE s.ref_practice_id = pve.in_record_id

            AND s.microservice_status = 'Developed'

      )

    ORDER BY random()

    LIMIT v_limit;



END;

$function$