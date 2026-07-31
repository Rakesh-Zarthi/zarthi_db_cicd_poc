CREATE OR REPLACE FUNCTION public.etl_sync_new_added_requests_nodes()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

BEGIN





-- =========================

-- UPDATE REQUESTS IMMEDIATE PARENT

-- =========================

WITH parent_mapping AS (



    SELECT

        ref_requests_record_id,

        immediate_parent

    FROM public.requests_services



    UNION ALL



    SELECT

        ref_requests_record_id,

        immediate_parent

    FROM public.requests_staffing



    UNION ALL



    SELECT

        ref_requests_in_record_id AS ref_requests_record_id,

        immediate_parent

    FROM public.requests_sku_roles



)

UPDATE public.requests r

SET ref_requests_in_record_id_immediate_parent =

    p.immediate_parent

FROM parent_mapping p

WHERE r.in_record_id = p.ref_requests_record_id

  AND r.ref_requests_in_record_id_immediate_parent

      IS DISTINCT FROM p.immediate_parent;



-- =========================

-- UPDATE REQUESTS SERVICES SKU

-- =========================

UPDATE public.requests r

SET ref_services_sku_in_record_id = rs.ref_services_sku

FROM public.requests_services rs

WHERE r.in_record_id = rs.ref_requests_record_id

  AND r.module = 'Services'

  AND r.ref_services_sku_in_record_id

      IS DISTINCT FROM rs.ref_services_sku;



 --=========================

-- UPDATE REQUESTS OWNER

-- =========================

UPDATE public.requests r

SET ref_users_in_record_id_owner = r.owner

WHERE r.ref_users_in_record_id_owner

      IS DISTINCT FROM r.owner;







END;

$function$