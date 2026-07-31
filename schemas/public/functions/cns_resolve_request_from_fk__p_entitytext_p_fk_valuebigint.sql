CREATE OR REPLACE FUNCTION public.cns_resolve_request_from_fk(p_entity text, p_fk_value bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_request_id bigint;

BEGIN

    CASE p_entity



        ------------------------------------------------------------------

        -- GROUP: OWNER REQUEST (STRICT)

        ------------------------------------------------------------------

        WHEN 'groups' THEN

            SELECT ref_requests_in_record_id_group_owner

              INTO v_request_id

              FROM public.groups

             WHERE in_record_id = p_fk_value;



        ------------------------------------------------------------------

        -- GROUP MEMBERS: MEMBER REQUEST (SELF)

        ------------------------------------------------------------------

        WHEN 'groups_members' THEN

            SELECT ref_requests_in_record_id_members

              INTO v_request_id

              FROM public.groups_members

             WHERE in_record_id = p_fk_value;



        ------------------------------------------------------------------

        -- SYSTEM MEETINGS: CREATOR REQUEST

        ------------------------------------------------------------------

        WHEN 'system_scheduled_meetings' THEN

            SELECT ref_requests_in_record_id_meeting_created_by

              INTO v_request_id

              FROM public.system_scheduled_meetings

             WHERE in_record_id = p_fk_value;



        ------------------------------------------------------------------

        -- MEETING MOM: GROUP OWNER (STRICT)

        ------------------------------------------------------------------

        WHEN 'meeting_mom' THEN

            SELECT g.ref_requests_in_record_id_group_owner

              INTO v_request_id

              FROM public.meeting_mom mm

              JOIN public.groups g

                ON g.in_record_id = mm.ref_groups_in_record_id_group

             WHERE mm.in_record_id = p_fk_value;



        ------------------------------------------------------------------

        -- SCRUM UPDATE: ANY GROUP MEMBER (OWNER INCLUDED)

        ------------------------------------------------------------------

        WHEN 'scrum_update_actionable' THEN

            SELECT gm.ref_requests_in_record_id_members

              INTO v_request_id

              FROM public.scrum_update_actionable s

              JOIN public.groups_members gm

                ON gm.ref_groups_in_record_id = s.ref_groups_in_record_id_group

             WHERE s.in_record_id = p_fk_value

             ORDER BY gm.is_group_owner DESC   -- prefer owner if present

             LIMIT 1;



        ------------------------------------------------------------------

        ELSE

            RAISE EXCEPTION

                'Γ¥î Unsupported entity for request resolution: %',

                p_entity

                USING ERRCODE = 'P0001';

    END CASE;



    ------------------------------------------------------------------

    -- SAFETY CHECK

    ------------------------------------------------------------------

    IF v_request_id IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Cannot resolve request for entity "%" with id %',

            p_entity,

            p_fk_value

            USING ERRCODE = 'P0001';

    END IF;



    RETURN v_request_id;

END;

$function$