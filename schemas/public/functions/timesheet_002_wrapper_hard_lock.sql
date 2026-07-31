CREATE OR REPLACE FUNCTION public.timesheet_002_wrapper_hard_lock()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$



DECLARE 



v_bypass BOOLEAN := FALSE;



BEGIN



    ------------------------------------------------------------------

    -- 001 Billing lock

    ------------------------------------------------------------------

    PERFORM public.timesheet_002_001_validate_billing_lock(

        TG_OP,

        OLD

    );



    ------------------------------------------------------------------

    -- 002 Approved update lock

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN

        PERFORM public.timesheet_002_002_validate_approved_update_lock(

            TG_OP,

            NEW,

            OLD

        );

    END IF;



    ------------------------------------------------------------------

    -- 003 Approved delete lock

    ------------------------------------------------------------------

    IF TG_OP = 'DELETE' THEN

        PERFORM public.timesheet_002_003_validate_approved_delete_lock(

            TG_OP,

            OLD

        );

    END IF;



    ------------------------------------------------------------------

    -- FINAL RETURN (correct pattern)

    ------------------------------------------------------------------

    IF TG_OP = 'DELETE' THEN

        RETURN OLD;

    ELSE

        RETURN NEW;

    END IF;

END;

$function$