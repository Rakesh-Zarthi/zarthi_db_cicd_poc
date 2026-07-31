CREATE OR REPLACE FUNCTION public.timesheet_002_002_validate_approved_update_lock(p_operation text, p_new timesheet, p_old timesheet)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

BEGIN

    IF p_operation = 'UPDATE'

       AND p_old.status = 'Approve'

       AND (

            p_new.from_date_time IS DISTINCT FROM p_old.from_date_time

         OR p_new.to_date_time   IS DISTINCT FROM p_old.to_date_time

         OR p_new.ref_users_in_record_id_professional IS DISTINCT FROM p_old.ref_users_in_record_id_professional

         OR p_new.ref_requests_in_record_id_request   IS DISTINCT FROM p_old.ref_requests_in_record_id_request

       ) THEN

        RAISE EXCEPTION

            'Γ¥î Approved timesheet % is locked and only status may be changed.',

            p_old.in_record_id;

    END IF;

END;

$function$