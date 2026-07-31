CREATE OR REPLACE FUNCTION public.check_requests_self_open_actionables(p_request_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_count bigint;

BEGIN



WITH actionable_links AS (



    ------------------------------------------------------------------

    -- subject + assigned_to

    ------------------------------------------------------------------

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

        AND a.actionable_status IS NOT NULL

        AND a.actionable_status::text NOT IN ('Complete','Discard')



    UNION ALL



    ------------------------------------------------------------------

    -- step assigned request

    ------------------------------------------------------------------

    SELECT

        s.ref_actionables_in_record_id AS actionable_id,

        s.ref_requests_in_record_id_assigned_to AS request_id

    FROM public.actionables_steps s

    WHERE

        s.ref_requests_in_record_id_assigned_to IS NOT NULL

        AND s.status IS NOT NULL

        AND s.status::text NOT IN ('Complete','Discard')



    UNION ALL



    ------------------------------------------------------------------

    -- subject request via step context

    ------------------------------------------------------------------

    SELECT

        s.ref_actionables_in_record_id AS actionable_id,

        a.request_subject AS request_id

    FROM public.actionables_steps s

    JOIN public.actionables a

      ON a.in_record_id = s.ref_actionables_in_record_id::bigint

    WHERE

        (s.ref_users_in_record_id_owner IS NOT NULL

         OR s.ref_requests_in_record_id_assigned_to IS NOT NULL)

        AND a.request_subject IS NOT NULL

        AND s.status IS NOT NULL

        AND s.status::text NOT IN ('Complete','Discard')

)



SELECT COUNT(DISTINCT actionable_id)

INTO v_count

FROM actionable_links

WHERE request_id::bigint = p_request_id;



------------------------------------------------------------------

-- Notice messages

------------------------------------------------------------------

IF v_count = 0 THEN

    RAISE NOTICE

        'Request % has no open actionables.',

        p_request_id;

ELSE

    RAISE NOTICE

        'Request % has open actionables.',

        p_request_id;

END IF;



RETURN COALESCE(v_count,0);



END;

$function$