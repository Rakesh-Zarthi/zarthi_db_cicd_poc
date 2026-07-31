CREATE OR REPLACE FUNCTION public.timesheet_002_003_validate_approved_delete_lock(p_operation text, p_old timesheet)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

BEGIN

    IF p_operation = 'DELETE'

       AND p_old.status = 'Approve' THEN

        RAISE EXCEPTION

            'Γ¥î Approved timesheet % cannot be deleted.',

            p_old.in_record_id;

    END IF;

END;

$function$