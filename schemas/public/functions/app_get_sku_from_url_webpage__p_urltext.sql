CREATE OR REPLACE FUNCTION public.app_get_sku_from_url_webpage(p_url text)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_sku_id bigint;

BEGIN



    ------------------------------------------------------------------

    -- Step 1: Try page_url

    ------------------------------------------------------------------

    SELECT ref_services_sku_in_record_id

    INTO v_sku_id

    FROM public.webpages

    WHERE page_url = p_url

    LIMIT 1;



    ------------------------------------------------------------------

    -- Step 2: If no row found, fallback

    ------------------------------------------------------------------

    IF NOT FOUND THEN

        SELECT ref_services_sku_in_record_id

        INTO v_sku_id

        FROM public.webpages

        WHERE "301_routing_url" = p_url

        LIMIT 1;

    END IF;



    ------------------------------------------------------------------

    RETURN v_sku_id;



END;

$function$