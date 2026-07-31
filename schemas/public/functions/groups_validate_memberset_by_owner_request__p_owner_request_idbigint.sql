CREATE OR REPLACE FUNCTION public.groups_validate_memberset_by_owner_request(p_owner_request_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_group_id bigint;

BEGIN

    SELECT g.in_record_id

    INTO v_group_id

    FROM public.groups g

    WHERE g.ref_requests_in_record_id_group_owner = p_owner_request_id

    ORDER BY g.in_record_id DESC

    LIMIT 1;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'No group found for owner request_id %.',

            p_owner_request_id;

    END IF;



    PERFORM public.groups_validate_memberset_core(v_group_id);

END;

$function$