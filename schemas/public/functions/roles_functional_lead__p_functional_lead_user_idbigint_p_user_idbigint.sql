CREATE OR REPLACE FUNCTION public.roles_functional_lead(p_functional_lead_user_id bigint DEFAULT NULL::bigint, p_user_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(functional_lead_id bigint, functional_lead_user_uuid uuid, functional_lead_name text, user_id bigint, user_uuid uuid, user_name text, user_email text, practice text, region text)
 LANGUAGE sql
 STABLE
AS $function$

SELECT

    fl.in_record_id AS functional_lead_id,

    fl.user_id      AS functional_lead_user_uuid,



    concat_ws(

        ' ',

        fl.first_name,

        COALESCE(fl.last_name, '.'),

        '(' || split_part(lower(fl.email_address), '@', 1) || ')'

    ) AS functional_lead_name,



    u.in_record_id AS user_id,

    u.user_id      AS user_uuid,



    concat_ws(

        ' ',

        u.first_name,

        COALESCE(u.last_name, '.'),

        '(' || split_part(lower(u.email_address), '@', 1) || ')'

    ) AS user_name,



    u.email_address AS user_email,

    p.practice_name_corporate_unit AS practice,

    h.hive_name AS region

FROM public.users u

JOIN public.users_internal ui

  ON ui.in_ref_users_in_record_id = u.in_record_id

JOIN public.users fl

  ON fl.in_record_id = ui.ref_users_in_record_id_primary_governance_board

LEFT JOIN public.practices p

  ON p.in_record_id = ui.ref_practice_in_record_id

LEFT JOIN public.hive_location h

  ON h.in_record_id = ui.ref_hive_location_in_record_id

WHERE

    (p_functional_lead_user_id IS NULL

        OR fl.in_record_id = p_functional_lead_user_id)

AND

    (p_user_id IS NULL

        OR u.in_record_id = p_user_id)

ORDER BY

    functional_lead_name,

    user_name;

$function$