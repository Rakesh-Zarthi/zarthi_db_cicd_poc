CREATE OR REPLACE FUNCTION public.trg_enforce_meeting_completion()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_actionable_id    bigint;

    v_actionable_time  timestamp;

    v_meeting_id       bigint;

BEGIN

    ------------------------------------------------------------------

    -- Fire ONLY on transition ΓåÆ Complete

    ------------------------------------------------------------------

    IF NEW.actionable_status <> 'Complete'

       OR OLD.actionable_status = 'Complete'

       OR NEW.actionable_category <> 'Meeting Management'

       OR NEW.actionable_name <> 'Schedule Meeting'

    THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 1∩╕ÅΓâú Fetch latest completed Schedule Meeting actionable

    ------------------------------------------------------------------

    SELECT a.in_record_id,

           a.actionable_completion_time

    INTO v_actionable_id,

         v_actionable_time

    FROM public.actionables a

    WHERE a.request_subject     = NEW.request_subject

      AND a.actionable_category = 'Meeting Management'

      AND a.actionable_name     = 'Schedule Meeting'

      AND a.actionable_status   = 'Complete'

    ORDER BY a.actionable_completion_time DESC

    LIMIT 1;



    IF v_actionable_id IS NULL THEN

        RAISE EXCEPTION

            'Meeting completion denied. No completed "Schedule Meeting" actionable exists for request %.',

            NEW.request_subject

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- 2∩╕ÅΓâú Lock per actionable (prevents race conditions)

    ------------------------------------------------------------------

    PERFORM pg_advisory_xact_lock(v_actionable_id);



    ------------------------------------------------------------------

    -- 3∩╕ÅΓâú Fetch meeting created AFTER actionable completion time

    ------------------------------------------------------------------

    SELECT m.in_record_id

    INTO v_meeting_id

    FROM public.system_scheduled_meetings m

    WHERE m.ref_requests_in_record_id_meeting_created_by =

          NEW.request_subject

      AND m.in_added_time >= v_actionable_time

    ORDER BY m.in_added_time ASC

    LIMIT 1;



    IF v_meeting_id IS NULL THEN

        RAISE EXCEPTION

            'Meeting completion denied. No meeting exists for completed actionable %.',

            v_actionable_id

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- 4∩╕ÅΓâú Enforce meeting completeness

    ------------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.system_scheduled_meetings m

        WHERE m.in_record_id = v_meeting_id

          AND (

                m.meeting_title IS NULL

             OR m.meeting_start_datetime IS NULL

             OR m.meeting_end_datetime IS NULL

          )

    ) THEN

        RAISE EXCEPTION

            'Meeting completion denied. Meeting % is incomplete (title/start/end required).',

            v_meeting_id

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- 5∩╕ÅΓâú Enforce ONE ACTIONABLE ΓåÆ ONE MEETING

    ------------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.system_scheduled_meetings m

        WHERE m.ref_requests_in_record_id_meeting_created_by =

              NEW.request_subject

          AND m.in_added_time >= v_actionable_time

          AND m.in_record_id <> v_meeting_id

    ) THEN

        RAISE EXCEPTION

            'Meeting completion denied. Completed "Schedule Meeting" actionable (id=%) '

            'has already been consumed.',

            v_actionable_id

            USING ERRCODE = 'P0001';

    END IF;



    RETURN NEW;

END;

$function$