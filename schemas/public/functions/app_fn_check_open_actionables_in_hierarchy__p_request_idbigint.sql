CREATE OR REPLACE FUNCTION public.app_fn_check_open_actionables_in_hierarchy(p_request_id bigint)
 RETURNS TABLE(actionable_id bigint, request_id bigint)
 LANGUAGE plpgsql
AS $function$

BEGIN



RETURN QUERY



WITH RECURSIVE



------------------------------------------------------------------

-- Build actionable Γåö request mapping

------------------------------------------------------------------

actionable_links AS (



    -- subject + assigned_to

    SELECT

        a.in_record_id AS actionable_id,

        v.request_id

    FROM public.actionables a

    CROSS JOIN LATERAL (

        VALUES

            (a.request_subject),

            (a.actionables_assigned_to)

    ) v(request_id)

    WHERE

        v.request_id IS NOT NULL

        AND a.actionable_status NOT IN ('Complete','Discard')



    UNION ALL



    -- steps assigned to request

    SELECT

        s.ref_actionables_in_record_id AS actionable_id,

        s.ref_requests_in_record_id_assigned_to AS request_id

    FROM public.actionables_steps s

    WHERE

        s.ref_requests_in_record_id_assigned_to IS NOT NULL

        AND s.status NOT IN ('Complete','Discard')



    UNION ALL



    -- subject request from step context

    SELECT

        s.ref_actionables_in_record_id AS actionable_id,

        a.request_subject AS request_id

    FROM public.actionables_steps s

    JOIN public.actionables a

      ON a.in_record_id = s.ref_actionables_in_record_id

    WHERE

        a.request_subject IS NOT NULL

        AND s.status NOT IN ('Complete','Discard')

),



------------------------------------------------------------------

-- Parent links

------------------------------------------------------------------

parent_links AS (

    SELECT ref_requests_record_id AS child_id,

           immediate_parent       AS parent_id

    FROM public.requests_services



    UNION ALL



    SELECT ref_requests_record_id,

           immediate_parent

    FROM public.requests_staffing

),



------------------------------------------------------------------

-- Child links

------------------------------------------------------------------

child_links AS (

    SELECT immediate_parent       AS parent_id,

           ref_requests_record_id AS child_id

    FROM public.requests_services



    UNION ALL



    SELECT immediate_parent,

           ref_requests_record_id

    FROM public.requests_staffing

),



------------------------------------------------------------------

-- Descendants

------------------------------------------------------------------

down_tree AS (

    SELECT p_request_id AS req_id



    UNION ALL



    SELECT cl.child_id

    FROM down_tree dt

    JOIN child_links cl

      ON cl.parent_id = dt.req_id

),



------------------------------------------------------------------

-- Ancestors

------------------------------------------------------------------

up_tree AS (

    SELECT p_request_id AS req_id



    UNION ALL



    SELECT pl.parent_id

    FROM up_tree ut

    JOIN parent_links pl

      ON pl.child_id = ut.req_id

),



------------------------------------------------------------------

-- Complete hierarchy

------------------------------------------------------------------

full_tree AS (

    SELECT req_id FROM down_tree

    UNION

    SELECT req_id FROM up_tree

)



------------------------------------------------------------------

-- Find actionables involving hierarchy

------------------------------------------------------------------

SELECT DISTINCT

    al.actionable_id::bigint,

    al.request_id::bigint

FROM actionable_links al

JOIN full_tree ft

  ON ft.req_id = al.request_id;



END;

$function$