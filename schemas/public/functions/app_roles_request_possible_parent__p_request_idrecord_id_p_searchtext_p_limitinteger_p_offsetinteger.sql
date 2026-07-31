CREATE OR REPLACE FUNCTION public.app_roles_request_possible_parent(p_request_id record_id, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
 RETURNS TABLE(current_request_id record_id, current_owner record_id, current_status text, current_summary text, current_immediate_parent record_id, possible_parents bigint[], possible_parent_summaries text[])
 LANGUAGE plpgsql
 STABLE
AS $function$



DECLARE

    v_current_role             bigint;

    v_current_immediate_parent bigint;

BEGIN



    ------------------------------------------------------------------

    -- Resolve current role request

    ------------------------------------------------------------------

    SELECT

        rsr.ref_services_sku_roles_in_record_id,

        rsr.immediate_parent

    INTO

        v_current_role,

        v_current_immediate_parent

    FROM public.requests_sku_roles rsr

    WHERE rsr.ref_requests_in_record_id = p_request_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Role mapping not found for request %',

            p_request_id;

    END IF;



    ------------------------------------------------------------------

    -- Return possible parents

    ------------------------------------------------------------------

    RETURN QUERY



    WITH possible_parents_cte AS (



        SELECT

            parent_req.in_record_id,

            parent_req.summary::text



        FROM public.requests parent_req



        LEFT JOIN public.requests_sku_roles parent_rsr

            ON parent_rsr.ref_requests_in_record_id =

               parent_req.in_record_id



        LEFT JOIN public.services_sku_roles parent_role

            ON parent_role.in_record_id =

               parent_rsr.ref_services_sku_roles_in_record_id



        LEFT JOIN LATERAL (



            SELECT

                CASE



                    WHEN parent_req.module = 'Problem'

                         AND parent_req.status <> ALL (ARRAY['Backlog','Close'])

                    THEN TRUE



                    WHEN parent_req.module = 'Services'

                         AND parent_req.status <> ALL (ARRAY['Backlog','Close'])

                    THEN TRUE



                    WHEN parent_req.module = 'Staffing'

                         AND parent_req.status <> ALL (ARRAY['Backlog','Close'])

                    THEN TRUE



                    WHEN parent_req.module = 'Roles'

                         AND COALESCE(parent_role.all_roles, FALSE)

                    THEN TRUE



                    WHEN parent_req.module = 'Roles'

                         AND parent_req.status <> ALL (ARRAY['Backlog','Close'])

                         AND EXISTS (

                                SELECT 1

                                FROM public.roles_dependency rd

                                WHERE rd.ref_services_sku_roles_in_record_id_parent =

                                      parent_rsr.ref_services_sku_roles_in_record_id

                                  AND rd.ref_services_sku_roles_in_record_id_child =

                                      v_current_role

                         )

                    THEN TRUE



                    ELSE FALSE



                END AS can_move



        ) validation ON TRUE



        WHERE parent_req.in_record_id <> p_request_id

          AND parent_req.in_record_id <>

              COALESCE(v_current_immediate_parent, -1)

          AND validation.can_move



          AND (

                p_search IS NULL

                OR btrim(p_search) = ''

                OR parent_req.summary ILIKE '%' || p_search || '%'

              )



        ORDER BY parent_req.in_record_id



        LIMIT GREATEST(COALESCE(p_limit, 20), 0)

        OFFSET GREATEST(COALESCE(p_offset, 0), 0)

    )



    SELECT

        cur.in_record_id::public.record_id,

        cur.owner::public.record_id,

        cur.status::text,

        cur.summary::text,

        v_current_immediate_parent::public.record_id,



        COALESCE(

            array_agg(

                ppc.in_record_id

                ORDER BY ppc.in_record_id

            ) FILTER (WHERE ppc.in_record_id IS NOT NULL),

            ARRAY[]::bigint[]

        ) AS possible_parents,



        COALESCE(

            array_agg(

                ppc.summary

                ORDER BY ppc.in_record_id

            ) FILTER (WHERE ppc.summary IS NOT NULL),

            ARRAY[]::text[]

        ) AS possible_parent_summaries



    FROM public.requests cur



    LEFT JOIN possible_parents_cte ppc

        ON TRUE



    WHERE cur.in_record_id = p_request_id

      AND cur.module = 'Roles'

      AND cur.status <> ALL (ARRAY['Backlog','Close'])



    GROUP BY

        cur.in_record_id,

        cur.owner,

        cur.status,

        cur.summary;



END;

$function$