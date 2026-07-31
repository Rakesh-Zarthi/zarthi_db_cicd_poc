CREATE OR REPLACE FUNCTION public.groups_require_create_actionable()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

DECLARE

    v_key         text;

    v_payload     jsonb;

    v_actionable  bigint;

    v_request_id  bigint;

BEGIN

    ------------------------------------------------------------------

    -- Canonical binding key (MUST match writer)

    ------------------------------------------------------------------

    v_key :=

        public.cns_actionable_binding_key(

            'Collaborations',   -- canonical category

            'Create Group'      -- canonical name

        );



    ------------------------------------------------------------------

    -- Fetch transaction-scoped binding

    ------------------------------------------------------------------

    v_payload := current_setting(v_key, true)::jsonb;



    IF v_payload IS NULL THEN

        RAISE EXCEPTION

            'Group creation denied. No completed "Create Group" actionable exists in this transaction.'

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Payload integrity validation

    ------------------------------------------------------------------

    IF NOT (

        v_payload ? 'actionable_id'

        AND v_payload ? 'request_id'

        AND v_payload ? 'completed_by'

    ) THEN

        RAISE EXCEPTION

            'Group creation denied. Invalid actionable binding payload.'

            USING ERRCODE = 'P0001';

    END IF;



    v_actionable := (v_payload ->> 'actionable_id')::bigint;

    v_request_id := (v_payload ->> 'request_id')::bigint;



    ------------------------------------------------------------------

    -- Validate request ownership

    ------------------------------------------------------------------

    IF v_request_id <> NEW.ref_requests_in_record_id_group_owner THEN

        RAISE EXCEPTION

            'Group creation denied. Actionable request % does not match group owner request %.',

            v_request_id,

            NEW.ref_requests_in_record_id_group_owner

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Advisory lock to prevent parallel consumption

    ------------------------------------------------------------------

    PERFORM pg_advisory_xact_lock(v_actionable);



    RETURN NULL;  -- AFTER INSERT constraint trigger

END;

$function$