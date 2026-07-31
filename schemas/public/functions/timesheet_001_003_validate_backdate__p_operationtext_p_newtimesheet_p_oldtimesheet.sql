CREATE OR REPLACE FUNCTION public.timesheet_001_003_validate_backdate(p_operation text, p_new timesheet, p_old timesheet)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

BEGIN

    IF p_operation = 'INSERT'

       OR (

            p_operation = 'UPDATE'

            AND p_new.from_date_time IS DISTINCT FROM p_old.from_date_time

          )

    THEN

        IF (p_new.from_date_time).date_part < current_date - 7 THEN

            RAISE EXCEPTION

                'Γ¥î Timesheet entries older than 7 days are not allowed.';

        END IF;

    END IF;

END;

$function$