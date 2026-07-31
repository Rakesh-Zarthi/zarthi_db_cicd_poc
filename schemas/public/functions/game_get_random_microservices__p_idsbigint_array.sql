CREATE OR REPLACE FUNCTION public.game_get_random_microservices(p_ids bigint[])
 RETURNS TABLE(in_record_id bigint, microservice_name text)
 LANGUAGE plpgsql
 STABLE
AS $function$

DECLARE

    v_count INT;

BEGIN

    -- Step 1: Count valid records

    SELECT COUNT(*)

    INTO v_count

    FROM public.services_sku s

    WHERE s.in_record_id = ANY(p_ids)

      AND s.microservice_status NOT IN ('Deprecated', 'Identified');



    -- Step 2: Enforce business rule

    IF v_count < 5 THEN

        RETURN; -- empty result

    END IF;



    -- Step 3: Return random 5 records

    RETURN QUERY

    SELECT s.in_record_id,

     s.microservice_name::TEXT

    FROM public.services_sku s

    WHERE s.in_record_id = ANY(p_ids)

      AND s.microservice_status NOT IN ('Deprecated', 'Identified')

    ORDER BY RANDOM()

    LIMIT 5;



END;

$function$