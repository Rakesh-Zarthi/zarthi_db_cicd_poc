CREATE OR REPLACE FUNCTION public.app_role_order_item_listing_paginated(p_request_id bigint, p_page integer DEFAULT 1, p_size integer DEFAULT 100, p_search text DEFAULT NULL::text)
 RETURNS TABLE(id text, name text, total_quantity numeric, order_type text, sign_off_type text)
 LANGUAGE plpgsql
 STABLE
AS $function$

DECLARE

    v_offset integer;

BEGIN

    ------------------------------------------------------------------

    -- Pagination

    ------------------------------------------------------------------

    p_page := GREATEST(COALESCE(p_page, 1), 1);

    p_size := GREATEST(COALESCE(p_size, 100), 1);



    v_offset := (p_page - 1) * p_size;



    RETURN QUERY

    WITH aggregated AS (



        ------------------------------------------------------------------

        -- Microservices (Aggregated by SKU)

        ------------------------------------------------------------------

        SELECT

            u.ref_services_sku_in_record_id::text AS id,

            MAX(ss.sku_name)::text AS name,

            SUM(u.quantity) AS total_quantity,

            'Microservice'::text AS order_type,

            MAX(u.quantity_unit)::text AS sign_off_type

        FROM public.usage u

        INNER JOIN public.services_sku ss

            ON ss.in_record_id = u.ref_services_sku_in_record_id

        WHERE

            u.ref_requests_in_record_id = p_request_id

            AND u.ref_services_sku_in_record_id IS NOT NULL

            AND u.status IN (     

                'Delivery In Progress'

            )

        GROUP BY

            u.ref_services_sku_in_record_id



        UNION ALL



        ------------------------------------------------------------------

        -- Tasks (Aggregated by Task Name)

        ------------------------------------------------------------------

        SELECT

            btrim(u.task)::text AS id,

            btrim(u.task)::text AS name,

            SUM(u.quantity) AS total_quantity,

            'Task'::text AS order_type,

            'Per Hour'::text AS sign_off_type

        FROM public.usage u

        WHERE

            u.ref_requests_in_record_id = p_request_id

            AND u.ref_services_sku_in_record_id IS NULL

            AND u.task IS NOT NULL

            AND btrim(u.task) <> ''

            AND u.status IN (           

                'Delivery In Progress'

            )

        GROUP BY

            btrim(u.task)

    )



    SELECT

        a.id,

        a.name,

        a.total_quantity,

        a.order_type,

        a.sign_off_type

    FROM aggregated a

    WHERE

        p_search IS NULL

        OR btrim(p_search) = ''

        OR a.name ILIKE '%' || btrim(p_search) || '%'

    ORDER BY

        a.name,

        a.order_type,

        a.id

    OFFSET v_offset

    LIMIT p_size;



END;

$function$