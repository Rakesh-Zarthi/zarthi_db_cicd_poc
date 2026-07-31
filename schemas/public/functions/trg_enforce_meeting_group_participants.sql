CREATE OR REPLACE FUNCTION public.trg_enforce_meeting_group_participants()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_meeting_id bigint;

    v_group_id   bigint;

BEGIN

    ------------------------------------------------------------------

    -- Resolve affected meeting

    ------------------------------------------------------------------

    v_meeting_id :=

        COALESCE(

            NEW.ref_meeting_in_record_id,

            OLD.ref_meeting_in_record_id

        );



    ------------------------------------------------------------------

    -- Resolve meeting's group

    ------------------------------------------------------------------

    SELECT m.ref_groups_in_record_id_meeting_created_at_group

    INTO v_group_id

    FROM public.system_scheduled_meetings m

    WHERE m.in_record_id = v_meeting_id;



    ------------------------------------------------------------------

    -- Rule 2b: Participant must belong to group

    ------------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.system_scheduled_meetings_participants mp

        LEFT JOIN public.groups_members gm

               ON gm.ref_groups_in_record_id = v_group_id

              AND gm.ref_requests_in_record_id_members =

                  mp.ref_users_in_record_id

        WHERE mp.ref_meeting_in_record_id = v_meeting_id

          AND gm.ref_requests_in_record_id_members IS NULL

        LIMIT 1

    ) THEN

        RAISE EXCEPTION

            'Meeting % contains participant(s) outside group %.',

            v_meeting_id, v_group_id

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Rule 2a: All group members must be participants

    ------------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.groups_members gm

        LEFT JOIN public.system_scheduled_meetings_participants mp

               ON mp.ref_meeting_in_record_id = v_meeting_id

              AND mp.ref_users_in_record_id =

                  gm.ref_requests_in_record_id_members

        WHERE gm.ref_groups_in_record_id = v_group_id

          AND mp.ref_users_in_record_id IS NULL

        LIMIT 1

    ) THEN

        RAISE EXCEPTION

            'Meeting % must include all members of group %.',

            v_meeting_id, v_group_id

            USING ERRCODE = 'P0001';

    END IF;



    RETURN NULL;

END;

$function$