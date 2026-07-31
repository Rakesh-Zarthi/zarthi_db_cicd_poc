CREATE OR REPLACE FUNCTION public.fn_problem_owner_cascade(p_request_id bigint, p_old_owner bigint, p_new_owner bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_module TEXT;

    v_skipped_actionables INT;

    v_skipped_steps INT;

BEGIN



----------------------------------------------------------------------

-- 1. Validate request

----------------------------------------------------------------------



SELECT r.module

INTO v_module

FROM public.requests r

WHERE r.in_record_id = p_request_id;



IF v_module IS NULL THEN

    RAISE EXCEPTION 'Request % does not exist in requests table.', p_request_id;

END IF;



IF v_module IS DISTINCT FROM 'Problem' THEN

    RAISE EXCEPTION 'Request % is not a Problem module.', p_request_id;

END IF;



WITH RECURSIVE



----------------------------------------------------------------------

-- HIERARCHY LOGIC (Services + Staffing + Roles)

----------------------------------------------------------------------



parent_links AS (

    SELECT ref_requests_record_id AS child_id, immediate_parent AS parent_id

    FROM public.requests_services

    UNION ALL

    SELECT ref_requests_record_id, immediate_parent

    FROM public.requests_staffing

    UNION ALL

    SELECT ref_requests_in_record_id AS child_id, immediate_parent AS parent_id

    FROM public.requests_sku_roles

),



child_links AS (

    SELECT immediate_parent AS parent_id, ref_requests_record_id AS child_id

    FROM public.requests_services

    UNION ALL

    SELECT immediate_parent, ref_requests_record_id

    FROM public.requests_staffing

    UNION ALL

    SELECT immediate_parent AS parent_id, ref_requests_in_record_id AS child_id

    FROM public.requests_sku_roles

),



up_tree AS (

    SELECT p_request_id AS req_id

    UNION ALL

    SELECT pl.parent_id

    FROM up_tree ut

    JOIN parent_links pl ON pl.child_id = ut.req_id

    WHERE pl.parent_id IS NOT NULL

      AND pl.parent_id <> ut.req_id

),



down_tree AS (

    SELECT p_request_id AS req_id

    UNION ALL

    SELECT cl.child_id

    FROM down_tree dt

    JOIN child_links cl ON cl.parent_id = dt.req_id

    WHERE cl.child_id <> dt.req_id

),



full_tree AS (

    SELECT req_id FROM up_tree

    UNION

    SELECT req_id FROM down_tree

),



----------------------------------------------------------------------

-- Skipped counts

----------------------------------------------------------------------



skipped_actionables AS (

    SELECT COUNT(*) AS cnt

    FROM public.actionables a

    WHERE a.request_subject IN (SELECT req_id FROM full_tree)

      AND a.actionable_owner IS NOT DISTINCT FROM p_old_owner

      AND a.actionable_status NOT IN ('Open','Planned','Drafted')

),



skipped_steps AS (

    SELECT COUNT(*) AS cnt

    FROM public.actionables_steps s

    JOIN public.actionables a

      ON a.in_record_id = s.ref_actionables_in_record_id

    WHERE a.request_subject IN (SELECT req_id FROM full_tree)

      AND s.ref_users_in_record_id_owner IS NOT DISTINCT FROM p_old_owner

      AND s.status NOT IN ('Open','Planned','Drafted')

),



----------------------------------------------------------------------

-- Update actionables

----------------------------------------------------------------------



updated_actionables AS (

    UPDATE public.actionables a

       SET actionable_owner = p_new_owner

     WHERE a.request_subject IN (SELECT req_id FROM full_tree)

       AND a.actionable_owner IS NOT DISTINCT FROM p_old_owner

       AND a.actionable_status IN ('Open','Planned','Drafted')

    RETURNING a.in_record_id

),



----------------------------------------------------------------------

-- Update steps

----------------------------------------------------------------------



updated_steps AS (

    UPDATE public.actionables_steps s

       SET ref_users_in_record_id_owner = p_new_owner

      FROM public.actionables a

     WHERE a.in_record_id = s.ref_actionables_in_record_id

       AND a.request_subject IN (SELECT req_id FROM full_tree)

       AND s.ref_users_in_record_id_owner IS NOT DISTINCT FROM p_old_owner

       AND s.status IN ('Open','Planned','Drafted')

    RETURNING s.in_record_id

),



----------------------------------------------------------------------

--Update usage (Services + Roles compatible)

----------------------------------------------------------------------



updated_usage AS (

    UPDATE public.usage u

       SET 



       --Consumer update (ID match driven)

       consumer = CASE

            WHEN u.ref_users_in_record_id_consumer IS NOT DISTINCT FROM p_old_owner

            THEN concat_ws(' ', u_cons.first_name, u_cons.last_name) || ' (' || split_part(lower(u_cons.email_address),'@',1) || ')'

            ELSE u.consumer

       END,



       ref_users_in_record_id_consumer = CASE

            WHEN u.ref_users_in_record_id_consumer IS NOT DISTINCT FROM p_old_owner

            THEN p_new_owner

            ELSE u.ref_users_in_record_id_consumer

       END,



       --Customer update (ID match driven)

       customer_name_bill_to = CASE

            WHEN u.ref_users_in_record_id_customer IS NOT DISTINCT FROM p_old_owner

            THEN concat_ws(' ', u_cust.first_name, u_cust.last_name) || ' (' || split_part(lower(u_cust.email_address),'@',1) || ')'

            ELSE u.customer_name_bill_to

       END,



       ref_users_in_record_id_customer = CASE

            WHEN u.ref_users_in_record_id_customer IS NOT DISTINCT FROM p_old_owner

            THEN p_new_owner

            ELSE u.ref_users_in_record_id_customer

       END



      FROM public.users u_cons,

           public.users u_cust



     WHERE u_cons.in_record_id = p_new_owner

       AND u_cust.in_record_id = p_new_owner



       --correct hierarchy

       AND u.ref_requests_in_record_id IN (SELECT req_id FROM full_tree)



       --Update logic

       AND (

           -- Roles usage: active lifecycle, regardless of actionable state

           (

               u.gen_zarthi_role_name IS NOT NULL

               AND u.status IN (

                   'Commercial Approval Pending',

                   'Delivery In Progress',

                   'Pending Sign-Off'

               )

           )

           OR

           -- Services/Staffing: only if actionable is still open

           (

               u.gen_zarthi_role_name IS NULL

               AND u.status = 'Awaiting Approval'

               AND EXISTS (

                   SELECT 1

                   FROM public.actionables a2

                   JOIN public.actionables_steps s2

                     ON s2.ref_actionables_in_record_id = a2.in_record_id

                   WHERE a2.request_subject = u.ref_requests_in_record_id

                     AND s2.status IN ('Open','Planned','Drafted')

               )

           )

       )



    RETURNING u.in_record_id

)



----------------------------------------------------------------------

-- Fetch skipped counts

----------------------------------------------------------------------



SELECT sa.cnt, ss.cnt

INTO v_skipped_actionables, v_skipped_steps

FROM skipped_actionables sa

CROSS JOIN skipped_steps ss;



----------------------------------------------------------------------

-- Notices

----------------------------------------------------------------------



IF v_skipped_actionables > 0 THEN

    RAISE NOTICE '% non-open actionables skipped.', v_skipped_actionables;

END IF;



IF v_skipped_steps > 0 THEN

    RAISE NOTICE '% non-open steps skipped.', v_skipped_steps;

END IF;



RAISE NOTICE

'Problem owner cascade complete for Request %, owner changed % ΓåÆ %',

p_request_id, p_old_owner, p_new_owner;



END;

$function$