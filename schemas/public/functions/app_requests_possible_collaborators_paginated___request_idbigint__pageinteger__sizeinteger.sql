CREATE OR REPLACE FUNCTION public.app_requests_possible_collaborators_paginated(_request_id bigint, _page integer DEFAULT 1, _size integer DEFAULT 10)
 RETURNS TABLE(collaborator_id bigint, collaborator_name text, collaborator_email text, total_count bigint)
 LANGUAGE sql
AS $function$



WITH filtered_users AS (

    SELECT

        u.in_record_id,

        concat_ws(

            ' ',

            u.first_name,

            COALESCE(u.last_name, '.'),

            '(' || split_part(lower(u.email_address), '@', 1) || ')'

        ) AS collaborator_name,

        u.email_address

    FROM users u

    WHERE

        -- Exclude request owner

        u.in_record_id <> (

            SELECT r.owner::bigint

            FROM requests r

            WHERE r.in_record_id = _request_id

            LIMIT 1

        )



        -- Exclude already added collaborators

        AND NOT EXISTS (

            SELECT 1

            FROM requests_collaborators rc

            WHERE rc.ref_requests_in_record_id::bigint = _request_id

              AND rc.ref_users_in_record_id::bigint = u.in_record_id

        )

)



SELECT

    fu.in_record_id AS collaborator_id,

    fu.collaborator_name,

    fu.email_address AS collaborator_email,

    COUNT(*) OVER() AS total_count

FROM filtered_users fu

ORDER BY fu.in_record_id

LIMIT _size

OFFSET (_page - 1) * _size;



$function$