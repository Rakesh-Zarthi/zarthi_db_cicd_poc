CREATE OR REPLACE FUNCTION public.trg_meeting_reschedule_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    ------------------------------------------------------------------

    -- Exit immediately if this is NOT a reschedule

    ------------------------------------------------------------------

    IF

        NEW.meeting_start_datetime IS NOT DISTINCT FROM OLD.meeting_start_datetime

    AND NEW.meeting_end_datetime   IS NOT DISTINCT FROM OLD.meeting_end_datetime

    THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- NEW RULE: Rescheduling reason is mandatory

    ------------------------------------------------------------------

    IF NEW.rescheduling_reason IS NULL

       OR btrim(NEW.rescheduling_reason) = ''

    THEN

        RAISE EXCEPTION

            'Re-schedule denied. rescheduling_reason is mandatory when meeting time is changed.'

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Guard 1: Only start/end may change during reschedule

    ------------------------------------------------------------------

    IF

        NEW.meeting_title IS DISTINCT FROM OLD.meeting_title

     OR NEW.meeting_description IS DISTINCT FROM OLD.meeting_description

     OR NEW.meeting_status IS DISTINCT FROM OLD.meeting_status

     OR NEW.ref_groups_in_record_id_meeting_created_at_group

        IS DISTINCT FROM OLD.ref_groups_in_record_id_meeting_created_at_group

    THEN

        RAISE EXCEPTION

            'Re-schedule denied. Only meeting_start_datetime and meeting_end_datetime can be modified.'

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Guard 2: Meeting must not have started

    ------------------------------------------------------------------

    IF OLD.meeting_start_datetime < CURRENT_TIMESTAMP THEN

        RAISE EXCEPTION

            'Re-schedule denied. Meeting % has already started.',

            OLD.in_record_id

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Guard 3: New meeting time must be in the future

    ------------------------------------------------------------------

    IF NEW.meeting_start_datetime < CURRENT_TIMESTAMP THEN

        RAISE EXCEPTION

            'Re-schedule denied. New meeting time must be in the future.'

            USING ERRCODE = 'P0001';

    END IF;



    RETURN NEW;

END;

$function$