CREATE OR REPLACE FUNCTION public.app_requests_possible_collaborators(_request_id bigint)
 RETURNS TABLE(collaborator_id bigint[], collaborator_name text[], collaborator_email text[])
 LANGUAGE sql
AS $function$

SELECT

    array_agg(u.in_record_id ORDER BY u.in_record_id),

    array_agg(concat_ws(' ', u.first_name, COALESCE(u.last_name, '.'),

            '(' || split_part(lower(u.email_address), '@', 1) || ')')

        ORDER BY u.in_record_id),

    array_agg(u.email_address ORDER BY u.in_record_id)

FROM users u

WHERE NOT EXISTS (

        SELECT 1

        FROM requests r

        WHERE r.in_record_id = _request_id

          AND u.in_record_id = r.owner::bigint

)

AND NOT EXISTS (

        SELECT 1

        FROM requests_collaborators rc

        WHERE rc.ref_requests_in_record_id::bigint = _request_id

          AND rc.ref_users_in_record_id::bigint = u.in_record_id

);

$function$