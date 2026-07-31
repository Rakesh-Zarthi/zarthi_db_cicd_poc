CREATE OR REPLACE FUNCTION public.trg_enforce_mandatory_participant()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_meeting_id bigint;

    v_count      integer;

BEGIN

    ------------------------------------------------------------------

    -- Determine affected meeting

    ------------------------------------------------------------------

    v_meeting_id :=

        COALESCE(

            NEW.ref_meeting_in_record_id,

            OLD.ref_meeting_in_record_id

        );



    ------------------------------------------------------------------

    -- Check for at least one mandatory participant

    ------------------------------------------------------------------

    SELECT COUNT(*)

    INTO v_count

    FROM public.system_scheduled_meetings_participants p

    WHERE p.ref_meeting_in_record_id = v_meeting_id

      AND p.is_mandatory = true;



    IF v_count = 0 THEN

        RAISE EXCEPTION

            'Business rule violation: Meeting % must have at least one mandatory participant.',

            v_meeting_id

            USING ERRCODE = 'P0001';

    END IF;



    RETURN NULL;

END;

$function$