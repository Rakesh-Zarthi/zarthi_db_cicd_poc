CREATE OR REPLACE FUNCTION public.timesheet_002_001_validate_billing_lock(p_operation text, p_old timesheet)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_is_billed boolean;

BEGIN

    IF p_operation IN ('UPDATE','DELETE') THEN



        ------------------------------------------------------------------

        -- Only check if timesheet is linked to a usage

        ------------------------------------------------------------------

        IF p_old.ref_usage_in_record_id IS NOT NULL THEN



            SELECT EXISTS (

                SELECT 1

                FROM public."usage" u

                WHERE u.in_record_id = p_old.ref_usage_in_record_id

                    AND initcap(lower(trim(u.status))) = 'Billed'

            )

            INTO v_is_billed;



            IF v_is_billed THEN

                RAISE EXCEPTION

                    'Γ¥î Timesheet % is locked because its linked usage is Billed.',

                    p_old.in_record_id;

            END IF;



        END IF;



    END IF;

END;

$function$