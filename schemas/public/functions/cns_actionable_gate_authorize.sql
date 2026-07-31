CREATE OR REPLACE FUNCTION public.cns_actionable_gate_authorize()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_group_id     bigint;

    v_request_id   bigint;



    -- Backward compatible args

    v_entity       text;

    v_group_fk_col text;

    v_category     text;

    v_name         text;

BEGIN

    ------------------------------------------------------------------

    -- Read TG arguments safely (supports 4-arg and 5-arg triggers)

    ------------------------------------------------------------------

    v_entity       := TG_ARGV[0];

    v_group_fk_col := TG_ARGV[1];



    -- If trigger was defined with 5 args, category/name are at [3]/[4]

    -- If trigger was defined with 4 args, category/name are at [2]/[3]

    IF TG_NARGS >= 5 THEN

        v_category := TG_ARGV[3];

        v_name     := TG_ARGV[4];

    ELSE

        v_category := TG_ARGV[2];

        v_name     := TG_ARGV[3];

    END IF;



    ------------------------------------------------------------------

    -- Resolve GROUP from NEW

    ------------------------------------------------------------------

    v_group_id := public.cns_get_new_fk_value(NEW, v_group_fk_col);



    IF v_group_id IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Group reference is required.'

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- GROUP-SCOPED AUTHORIZATION

    -- For: Scrum Update, Send MOM

    ------------------------------------------------------------------

    IF v_name IN ('Scrum Update', 'Send MOM') THEN



        -- Ensure group has at least one member

        IF NOT EXISTS (

            SELECT 1

              FROM public.groups_members gm

             WHERE gm.ref_groups_in_record_id = v_group_id

        ) THEN

            RAISE EXCEPTION

                'Γ¥î Group % has no members; "%" not allowed.',

                v_group_id,

                v_name

                USING ERRCODE = 'P0001';

        END IF;



        -- Authorization PASSES here.

        -- Actual request binding is validated during CONSUME.

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- DEFAULT: STRICT OWNER-BASED AUTHORIZATION

    ------------------------------------------------------------------

    v_request_id := public.cns_resolve_request_from_fk(v_entity, v_group_id);



    PERFORM public.cns_require_completed_actionable(

        v_request_id,

        v_category,

        v_name

    );



    RETURN NEW;

END;

$function$