CREATE OR REPLACE FUNCTION public._usage_combo_rows(
    p_request_id bigint,
    p_professional_id bigint,
    p_task text
)
RETURNS TABLE
(
    in_record_id bigint,
    quantity numeric,
    rn integer
)
LANGUAGE sql
STABLE
AS
$function$
    SELECT
        u.in_record_id,
        u.quantity::numeric,
        row_number() OVER
        (
            ORDER BY
                u.quantity DESC,
                u.in_record_id
        ) AS rn
    FROM usage u
    WHERE u.ref_requests_in_record_id = p_request_id
      AND u.task = p_task
      AND u.status = 'Delivery In Progress'
      AND
      (
            u.ref_users_in_record_id_owner = p_professional_id
         OR u.ref_users_in_record_id_consumer = p_professional_id
         OR u.ref_users_in_record_id_customer = p_professional_id
      );
$function$;