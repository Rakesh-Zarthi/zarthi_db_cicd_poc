CREATE OR REPLACE FUNCTION public.ensure_actionable_completion_before_execution()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    ------------------------------------------------------------------

    -- Act ONLY on transition ΓåÆ Complete

    ------------------------------------------------------------------

    IF TG_OP <> 'UPDATE'

       OR NEW.actionable_status IS DISTINCT FROM 'Complete'

       OR OLD.actionable_status = 'Complete'

    THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Mandatory completion integrity

    ------------------------------------------------------------------

    IF NEW.completed_by IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Actionable % cannot be completed without completed_by.',

            NEW.in_record_id;

    END IF;



    IF NEW.actionable_completion_time IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Actionable % cannot be completed without completion time.',

            NEW.in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- Transaction-scoped advisory lock

    -- Guarantees single-consumer semantics

    ------------------------------------------------------------------

    PERFORM pg_advisory_xact_lock(NEW.in_record_id);



    RETURN NEW;

END;

$function$