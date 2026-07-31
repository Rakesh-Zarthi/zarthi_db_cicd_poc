CREATE OR REPLACE FUNCTION public.trg_meeting_lifecycle_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_now timestamptz := clock_timestamp();

BEGIN



-- INSERT rules 

--changed on 27/02/2026

    IF TG_OP = 'INSERT' THEN



        IF NEW.meeting_type = 'Scheduled'

           AND NEW.meeting_status <> 'Scheduled'

        THEN

            RAISE EXCEPTION

                'Scheduled meeting_type must start with status = Scheduled.';

        END IF;



        IF NEW.meeting_type = 'Instant'

           AND NEW.meeting_status <> 'On Going'

        THEN

            RAISE EXCEPTION

                'Instant meeting_type must start with status = On Going.';

        END IF;



    END IF;





    ------------------------------------------------------------------

    -- RESCHEDULE detection

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE'

       AND (

            NEW.meeting_start_datetime IS DISTINCT FROM OLD.meeting_start_datetime

         OR NEW.meeting_end_datetime   IS DISTINCT FROM OLD.meeting_end_datetime

       )

    THEN

        IF NEW.rescheduling_reason IS NULL

           OR btrim(NEW.rescheduling_reason) = ''

        THEN

            RAISE EXCEPTION

                'rescheduling_reason is mandatory when meeting time changes.';

        END IF;



        IF OLD.meeting_start_datetime <= v_now THEN

            RAISE EXCEPTION

                'Cannot reschedule a meeting that has already started.';

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- Status-specific rules

    ------------------------------------------------------------------

    IF NEW.meeting_status = 'Scheduled' THEN

        IF NEW.meeting_type = 'Scheduled'

           AND NEW.meeting_start_datetime < v_now

        THEN

            RAISE EXCEPTION

                'Scheduled meetings must start in the future.';

        END IF;



        IF NEW.meeting_type = 'Instant'

           AND NEW.meeting_start_datetime < v_now - INTERVAL '5 minutes'

        THEN

            RAISE EXCEPTION

                'Instant meetings cannot be backdated more than 5 minutes.';

        END IF;

    END IF;



    IF NEW.meeting_status = 'On Going' THEN

        IF NEW.meeting_start_datetime > v_now

           OR NEW.meeting_end_datetime < v_now

        THEN

            RAISE EXCEPTION

                'On Going meeting must span current time.';

        END IF;

    END IF;



    IF NEW.meeting_status = 'Completed' THEN

        IF NEW.meeting_end_datetime > v_now THEN

            RAISE EXCEPTION

                'Completed meeting cannot end in the future.';

        END IF;

    END IF;



    IF NEW.meeting_status = 'Cancelled'

       AND NEW.cancellation_reason IS NULL

    THEN

        RAISE EXCEPTION

            'Cancellation reason is mandatory.';

    END IF;



    RETURN NEW;

END;

$function$