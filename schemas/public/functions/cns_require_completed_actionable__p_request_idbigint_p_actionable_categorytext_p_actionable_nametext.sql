CREATE OR REPLACE FUNCTION public.cns_require_completed_actionable(p_request_id bigint, p_actionable_category text, p_actionable_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_key            text;

    v_raw            text;

    v_payload        jsonb;

    v_bound_request  bigint;

BEGIN

    ------------------------------------------------------------------

    -- Mandatory input validation

    ------------------------------------------------------------------

    IF p_request_id IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î request_id is required.'

            USING ERRCODE = 'P0001';

    END IF;



    IF p_actionable_category IS NULL

       OR p_actionable_name IS NULL

    THEN

        RAISE EXCEPTION

            'Γ¥î actionable category and name are required.'

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Canonical binding key

    ------------------------------------------------------------------

    v_key :=

        public.cns_actionable_binding_key(

            p_actionable_category,

            p_actionable_name

        );



    ------------------------------------------------------------------

    -- Safe read of transaction-local binding

    ------------------------------------------------------------------

    v_raw := current_setting(v_key, true);



    -- Treat NULL, empty, or whitespace as "not bound"

    IF v_raw IS NULL OR btrim(v_raw) = '' THEN

        RAISE EXCEPTION

            'Γ¥î Operation denied. No completed "%" actionable exists for request %.',

            p_actionable_name,

            p_request_id

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Safe JSON parse

    ------------------------------------------------------------------

    BEGIN

        v_payload := v_raw::jsonb;

    EXCEPTION

        WHEN others THEN

            RAISE EXCEPTION

                'Γ¥î Invalid binding payload for actionable "%".',

                p_actionable_name

                USING ERRCODE = 'P0001';

    END;



    ------------------------------------------------------------------

    -- Validate binding structure

    ------------------------------------------------------------------

    IF NOT (v_payload ? 'request_id') THEN

        RAISE EXCEPTION

            'Γ¥î Binding payload missing request_id for actionable "%".',

            p_actionable_name

            USING ERRCODE = 'P0001';

    END IF;



    v_bound_request := (v_payload ->> 'request_id')::bigint;



    ------------------------------------------------------------------

    -- Enforce request affinity

    ------------------------------------------------------------------

    IF v_bound_request IS NULL

       OR v_bound_request <> p_request_id

    THEN

        RAISE EXCEPTION

            'Γ¥î Actionable "%" is not bound to request %.',

            p_actionable_name,

            p_request_id

            USING ERRCODE = 'P0001';

    END IF;



    -- All checks passed

    RETURN;

END;

$function$