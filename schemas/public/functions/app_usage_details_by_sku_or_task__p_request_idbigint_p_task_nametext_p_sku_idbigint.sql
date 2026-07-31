CREATE OR REPLACE FUNCTION public.app_usage_details_by_sku_or_task(p_request_id bigint, p_task_name text DEFAULT NULL::text, p_sku_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(microservice_name text, customer text, consumer text, request_owner text, request_owner_practice text, role_name text, quantity numeric, per_unit_price numeric, pending_quantity numeric, rejected_quantity numeric, in_progress_quantity numeric, sign_off_quantity numeric, delivered_quantity numeric, cancelled_quantity numeric)
 LANGUAGE plpgsql
 STABLE
AS $function$

BEGIN



    IF p_request_id IS NULL THEN

        RAISE EXCEPTION 'request_id is required';

    END IF;



    IF (p_task_name IS NULL AND p_sku_id IS NULL)

       OR (p_task_name IS NOT NULL AND p_sku_id IS NOT NULL)

    THEN

        RAISE EXCEPTION

        'Provide either p_task_name or p_sku_id';

    END IF;



    RETURN QUERY



    WITH filtered_usage AS

    (

        SELECT u.*

        FROM public.usage u

        WHERE u.ref_requests_in_record_id = p_request_id

          AND (

                (

                    p_sku_id IS NOT NULL

                    AND u.ref_services_sku_in_record_id = p_sku_id

                )

                OR

                (

                    p_task_name IS NOT NULL

                    AND u.ref_services_sku_in_record_id IS NULL

                    AND u.task = p_task_name

                )

              )

    )

    SELECT

        MAX(

            CASE

                WHEN p_sku_id IS NOT NULL

                THEN s.sku_name

                ELSE fu.consumer

            END

        )::TEXT AS microservice_name,



        MAX(fu.customer_name_bill_to)::TEXT AS customer,



        -- Fetch Request Summary instead of Consumer Name

        MAX(r.summary)::TEXT AS consumer,



        MAX(fu.solution_owner)::TEXT AS request_owner,



        MAX(fu.solution_owner_practice)::TEXT AS request_owner_practice,



        MAX(fu.gen_zarthi_role_name)::TEXT AS role_name,



        SUM(

            CASE

                WHEN fu.status IN

                (

                    'Pending Sign-Off',

                    'Commercial Approval Pending',

                    'Delivery In Progress',

                    'Delivered'

                )

                THEN fu.quantity

                ELSE 0

            END

        )::NUMERIC AS quantity,



        MAX(fu.unit_price)::NUMERIC AS per_unit_price,



        SUM(

            CASE

                WHEN fu.status IN

                (

                    'Awaiting Approval',

                    'Approved',

                    'Billed','Commercial Approval Pending'

                )

                THEN fu.quantity

                ELSE 0

            END

        )::NUMERIC AS pending_quantity,



        SUM(

            CASE

                WHEN fu.status = 'Rejected'

                THEN fu.quantity

                ELSE 0

            END

        )::NUMERIC AS rejected_quantity,



        SUM(

            CASE

                WHEN fu.status = 'Delivery In Progress'

                THEN fu.quantity

                ELSE 0

            END

        )::NUMERIC AS in_progress_quantity,



        SUM(

            CASE

                WHEN fu.status IN

                (

                    'Pending Sign-Off'

                    

                )

                THEN fu.quantity

                ELSE 0

            END

        )::NUMERIC AS sign_off_quantity,



        SUM(

            CASE

                WHEN fu.status = 'Delivered'

                THEN fu.quantity

                ELSE 0

            END

        )::NUMERIC AS delivered_quantity,



        SUM(

            CASE

                WHEN fu.status = 'Cancelled'

                THEN fu.quantity

                ELSE 0

            END

        )::NUMERIC AS cancelled_quantity



    FROM filtered_usage fu

    LEFT JOIN public.services_sku s

        ON s.in_record_id = fu.ref_services_sku_in_record_id

    LEFT JOIN public.requests r

        ON r.in_record_id = fu.ref_requests_in_record_id;



END;

$function$