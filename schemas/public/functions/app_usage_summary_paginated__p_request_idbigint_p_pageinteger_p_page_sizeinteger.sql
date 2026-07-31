CREATE OR REPLACE FUNCTION public.app_usage_summary_paginated(p_request_id bigint, p_page integer DEFAULT 1, p_page_size integer DEFAULT 100)
 RETURNS TABLE(id bigint, skuid bigint, module_name text, sku_name text, task text, quantity numeric, delivered_quantity numeric, total_price numeric, consumer text, customer text, status text, role_name text, actionable_name text)
 LANGUAGE plpgsql
 STABLE
AS $function$

DECLARE

    v_offset INTEGER;

    v_module_name TEXT;

BEGIN



    p_page := GREATEST(COALESCE(p_page, 1), 1);

    p_page_size := GREATEST(COALESCE(p_page_size, 100), 1);



    v_offset := (p_page - 1) * p_page_size;



    ------------------------------------------------------------------

    -- Request Module

    ------------------------------------------------------------------

    SELECT r.module::TEXT

    INTO v_module_name

    FROM public.requests r

    WHERE r.in_record_id = p_request_id;



    RETURN QUERY



    WITH usage_data AS

(

    SELECT

        u.in_record_id,

        u.ref_services_sku_in_record_id,

        u.sku,

        u.task,



        u.quantity AS quantity,



        u.gen_total_price,

        u.ref_requests_in_record_id,

        u.customer_name_bill_to,

        u.status,

        u.gen_zarthi_role_name,

        a.actionable_name,

        

        CASE

            WHEN u.status::TEXT = 'Delivered'

            THEN u.quantity

            ELSE 0::NUMERIC

        END AS delivered_quantity



    FROM public.usage u

    LEFT JOIN public.actionables a

        ON a.in_record_id =

           u.ref_actionables_in_record_immediate_consumer

    WHERE u.ref_requests_in_record_id = p_request_id

)



    ------------------------------------------------------------------

    -- SERVICE / STAFFING (NON-SKU)

    ------------------------------------------------------------------

    SELECT

        ud.in_record_id::BIGINT,

        ud.ref_services_sku_in_record_id::BIGINT,

        v_module_name::TEXT,

        ud.sku::TEXT,

        ud.task::TEXT,

        ud.quantity::NUMERIC,

        CASE

    WHEN ud.status = 'Delivered'

    THEN ud.quantity

    ELSE 0::NUMERIC

END AS delivered_quantity,

        ud.gen_total_price::NUMERIC,

        r2.summary::TEXT,

        ud.customer_name_bill_to::TEXT,

        ud.status::TEXT,

        ud.gen_zarthi_role_name::TEXT,

        ud.actionable_name::TEXT

    FROM usage_data ud

    LEFT JOIN requests r1 on ud.ref_requests_in_record_id = r1.in_record_id

    LEFT JOIN requests r2 on r1.ref_requests_in_record_id_immediate_parent = r2.in_record_id

    WHERE ud.ref_services_sku_in_record_id IS NULL

    AND v_module_name IN ('Services', 'Staffing')



    UNION ALL



    ------------------------------------------------------------------

    -- Task AGGREGATED

    ------------------------------------------------------------------



		    SELECT

		    NULL::BIGINT AS id,

		    NULL::BIGINT AS skuid,

		    v_module_name,

		    NULL::TEXT AS sku_name,

		    ud.task,

		    SUM(

        CASE

        WHEN ud.status IN (

            'Pending Sign-Off',

            'Delivered',

            'Delivery In Progress',

            'Commercial Approval Pending'

        )

        THEN ud.quantity

        ELSE 0::NUMERIC

        END

        )::NUMERIC AS quantity,

        SUM(

    CASE

        WHEN ud.status = 'Delivered'

        THEN ud.quantity

        ELSE 0::NUMERIC

    END

)::NUMERIC,

		    SUM(ud.gen_total_price) AS total_price,

		    r2.summary,

		    ud.customer_name_bill_to,

		    NULL::TEXT,

		    ud.gen_zarthi_role_name,

		    STRING_AGG(DISTINCT ud.actionable_name, ', ')

		FROM usage_data ud

		LEFT JOIN requests r1

		    ON ud.ref_requests_in_record_id = r1.in_record_id

		LEFT JOIN requests r2

		    ON r1.ref_requests_in_record_id_immediate_parent = r2.in_record_id

		WHERE v_module_name = 'Roles'

		  AND ud.ref_services_sku_in_record_id IS NULL

		GROUP BY

		    ud.task,

		    r2.summary,

		    ud.customer_name_bill_to,

		    ud.gen_zarthi_role_name



    UNION ALL



    ------------------------------------------------------------------

    -- SKU AGGREGATED

    ------------------------------------------------------------------

    SELECT

        NULL::BIGINT,

        ud.ref_services_sku_in_record_id::BIGINT,

        v_module_name::TEXT,

        s1.sku_name::TEXT,

        ud.task::TEXT,

        SUM(

        CASE

        WHEN ud.status IN (

            'Pending Sign-Off',

            'Delivered',

            'Delivery In Progress',

            'Commercial Approval Pending'

        )

        THEN ud.quantity

        ELSE 0::NUMERIC

        END

        )::NUMERIC AS quantity,

        SUM(

    CASE

        WHEN ud.status = 'Delivered'

        THEN ud.quantity

        ELSE 0::NUMERIC

    END

)::NUMERIC,

        SUM(ud.gen_total_price)::NUMERIC,

        r2.summary::TEXT,

        ud.customer_name_bill_to::TEXT,

        NULL::TEXT,

        ud.gen_zarthi_role_name::TEXT,

        ud.actionable_name::TEXT

    FROM usage_data ud

    JOIN services_sku s1 on ud.ref_services_sku_in_record_id = s1.in_record_id

    LEFT JOIN requests r1 on ud.ref_requests_in_record_id = r1.in_record_id

    LEFT JOIN requests r2 on r1.ref_requests_in_record_id_immediate_parent = r2.in_record_id

    WHERE ud.ref_services_sku_in_record_id IS NOT NULL

    GROUP BY

        ud.ref_services_sku_in_record_id,

        ud.task,

        r2.summary,

        ud.customer_name_bill_to,

        ud.gen_zarthi_role_name,

        ud.actionable_name,

        s1.sku_name



    ORDER BY 1 NULLS LAST, 2



    LIMIT p_page_size

    OFFSET v_offset;



END;

$function$