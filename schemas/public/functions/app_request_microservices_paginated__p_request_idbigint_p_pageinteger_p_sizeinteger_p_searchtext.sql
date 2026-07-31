CREATE OR REPLACE FUNCTION public.app_request_microservices_paginated(p_request_id bigint, p_page integer DEFAULT 1, p_size integer DEFAULT 10, p_search text DEFAULT NULL::text)
 RETURNS SETOF request_microservice_response
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$



WITH filtered_microservices AS (



    SELECT

        u.ref_requests_in_record_id::bigint AS request_id,



        ss.in_record_id::bigint AS microservice_in_record_id,



        ss.microservice_name::text AS microservice_name,



        COALESCE(SUM(u.quantity), 0)::bigint AS usage_count



    FROM public.usage u



    INNER JOIN public.services_sku ss

        ON ss.in_record_id = u.ref_services_sku_in_record_id



    WHERE

        u.ref_requests_in_record_id = p_request_id



        AND u.status = 'Delivery In Progress'



        AND (

            p_search IS NULL

            OR ss.microservice_name ILIKE '%' || p_search || '%'

        )



    GROUP BY

        u.ref_requests_in_record_id,

        ss.in_record_id,

        ss.microservice_name

)



SELECT

    fm.request_id,

    fm.microservice_in_record_id,

    fm.microservice_name,

    fm.usage_count,

    COUNT(*) OVER()::bigint AS total_count



FROM filtered_microservices fm



ORDER BY fm.microservice_name



LIMIT GREATEST(p_size, 1)



OFFSET GREATEST(

    (p_page - 1) * p_size,

    0

);



$function$