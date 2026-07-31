CREATE OR REPLACE FUNCTION public.cns_actionable_gate_consume()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_key         text;

    v_raw         text;

    v_payload     jsonb;

    v_actionable  bigint;

    v_request_id  bigint;

    v_group_id    bigint;

    v_owner_req   bigint;

BEGIN

    ------------------------------------------------------------------

    -- Resolve binding key

    ------------------------------------------------------------------

    v_key :=

        public.cns_actionable_binding_key(

            TG_ARGV[0],  -- category

            TG_ARGV[1]   -- actionable name

        );



    ------------------------------------------------------------------

    -- Safe read of transaction-local binding

    ------------------------------------------------------------------

    v_raw := current_setting(v_key, true);



    ------------------------------------------------------------------

    -- ≡ƒöÆ COLLABORATION ACTIONABLES REQUIRE COMPLETION

    ------------------------------------------------------------------

    IF v_raw IS NULL OR btrim(v_raw) = '' THEN

        IF TG_ARGV[0] = 'Collaborations' THEN

            RAISE EXCEPTION

                'Γ¥î Collaboration actionable "%" must be completed before consumption.',

                TG_ARGV[1]

                USING ERRCODE = 'P0001';

        END IF;



        -- Non-collaboration: silent no-op

        RETURN NULL;

    END IF;



    ------------------------------------------------------------------

    -- Parse binding payload safely

    ------------------------------------------------------------------

    BEGIN

        v_payload := v_raw::jsonb;

    EXCEPTION

        WHEN others THEN

            IF TG_ARGV[0] = 'Collaborations' THEN

                RAISE EXCEPTION

                    'Γ¥î Invalid binding payload for collaboration actionable "%".',

                    TG_ARGV[1]

                    USING ERRCODE = 'P0001';

            END IF;



            RETURN NULL;

    END;



    v_actionable := (v_payload ->> 'actionable_id')::bigint;

    v_request_id := (v_payload ->> 'request_id')::bigint;



    ------------------------------------------------------------------

    -- Resolve GROUP from NEW

    ------------------------------------------------------------------

    v_group_id :=

        public.cns_get_new_fk_value(NEW, TG_ARGV[3]);



    ------------------------------------------------------------------

    -- COLLABORATION ACTIONABLES: MEMBER OR OWNER

    ------------------------------------------------------------------

    IF TG_ARGV[0] = 'Collaborations' THEN



        IF NOT EXISTS (

            SELECT 1

              FROM public.groups_members gm

             WHERE gm.ref_groups_in_record_id = v_group_id

               AND gm.ref_requests_in_record_id_members = v_request_id

        ) THEN

            RAISE EXCEPTION

                'Γ¥î Actionable request % is not a member of group %.',

                v_request_id,

                v_group_id

                USING ERRCODE = 'P0001';

        END IF;



    ELSE

        ------------------------------------------------------------------

        -- NON-COLLABORATION: STRICT OWNER MATCH

        ------------------------------------------------------------------

        v_owner_req :=

            public.cns_resolve_request_from_fk(

                TG_ARGV[2],

                v_group_id

            );



        IF v_owner_req <> v_request_id THEN

            RAISE EXCEPTION

                'Γ¥î Actionable request % does not match owner request %',

                v_request_id,

                v_owner_req

                USING ERRCODE = 'P0001';

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- Single-consumer guarantee

    ------------------------------------------------------------------

    PERFORM pg_advisory_xact_lock(v_actionable);



    RETURN NULL;

END;

$function$