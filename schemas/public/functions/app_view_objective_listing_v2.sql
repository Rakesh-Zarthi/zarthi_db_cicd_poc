CREATE OR REPLACE FUNCTION public.app_view_objective_listing_v2()
 RETURNS TABLE(id bigint, dependent_requests bigint, closed_dependent_requests bigint, summary text, description text, status text, module text, solution_type text, quantity numeric, owner text, owner_account text, immediate_owner text, sku_id bigint, microservice_name text, created_time timestamp with time zone, close_timestamp timestamp with time zone, in_progress_timestamp timestamp with time zone, pause_timestamp timestamp with time zone, owner_id bigint, immediate_customer_id bigint, immediate_customer_account_id bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

 WITH dependent_childs AS (

         SELECT parent.immediate_parent,

            count(*) AS dependent_requests,

            count(*) FILTER (WHERE r_child.status::text = 'Close'::text) AS closed_dependent_requests

           FROM ( SELECT requests_services.immediate_parent,

                    requests_services.ref_requests_record_id

                   FROM requests_services

                UNION ALL

                 SELECT requests_staffing.immediate_parent,

                    requests_staffing.ref_requests_record_id

                   FROM requests_staffing) parent

             JOIN requests r_child ON r_child.in_record_id = parent.ref_requests_record_id::bigint

          GROUP BY parent.immediate_parent

        )

 SELECT r1.in_record_id AS id,

    COALESCE(dc.dependent_requests, 0::bigint) AS dependent_requests,

    COALESCE(dc.closed_dependent_requests, 0::bigint) AS closed_dependent_requests,

    r1.summary,

    r1.description,

    r1.status,

    r1.module,

    r1.solution_type,

    COALESCE(s1.quantity, st1.quantity) AS quantity,

    u1.user_name AS owner,

    u1.account_name AS owner_account,

    COALESCE(u2.user_name, u3.user_name, u1.user_name) AS immediate_owner,

    m1.in_record_id AS sku_id,

    m1.microservice_name,

    r1.in_added_time AS created_time,

    sta.close_timestamp,

    sta.in_progress_timestamp,

    sta.pause_timestamp,

    u1.id AS owner_id,

    COALESCE(u2.id, u3.id, u1.id) AS immediate_customer_id,

    COALESCE(u2.account_id, u3.account_id) AS immediate_customer_account_id

   FROM requests r1

     LEFT JOIN status_tracking_aggregate_v2 sta ON sta.request_id = r1.in_record_id

     LEFT JOIN dependent_childs dc ON dc.immediate_parent::bigint = r1.in_record_id

     LEFT JOIN requests_services s1 ON s1.ref_requests_record_id::bigint = r1.in_record_id

     LEFT JOIN requests_staffing st1 ON st1.ref_requests_record_id::bigint = r1.in_record_id

     LEFT JOIN services_sku m1 ON s1.ref_services_sku::bigint = m1.in_record_id

     LEFT JOIN users_universal u1 ON r1.owner::bigint = u1.id

     LEFT JOIN requests r2 ON s1.immediate_parent::bigint = r2.in_record_id

     LEFT JOIN users_universal u2 ON r2.owner::bigint = u2.id

     LEFT JOIN requests r2_staff ON st1.immediate_parent::bigint = r2_staff.in_record_id

     LEFT JOIN users_universal u3 ON r2_staff.owner::bigint = u3.id; $function$