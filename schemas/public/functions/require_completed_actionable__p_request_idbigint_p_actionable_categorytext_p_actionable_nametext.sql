CREATE OR REPLACE FUNCTION public.require_completed_actionable(p_request_id bigint, p_actionable_category text, p_actionable_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_key          text;

    v_payload_text text;

    v_payload      jsonb;

BEGIN

    ------------------------------------------------------------------

    -- Canonical binding key (single source of truth)

    ------------------------------------------------------------------

    v_key :=

        public.cns_actionable_binding_key(

            p_actionable_category,

            p_actionable_name

        );



    ------------------------------------------------------------------

    -- Read transaction-scoped binding SAFELY

    ------------------------------------------------------------------

    v_payload_text := current_setting(v_key, true);



    -- Guard 1: not set or empty

    IF v_payload_text IS NULL OR btrim(v_payload_text) = '' THEN

        RAISE EXCEPTION

            'Operation denied. No completed "%" actionable exists in this transaction for request %.',

            p_actionable_name,

            p_request_id

            USING ERRCODE = 'P0001';

    END IF;



    -- Guard 2: invalid JSON

    BEGIN

        v_payload := v_payload_text::jsonb;

    EXCEPTION

        WHEN invalid_text_representation THEN

            RAISE EXCEPTION

                'Corrupted actionable binding for "%" (%).',

                p_actionable_name,

                v_payload_text

                USING ERRCODE = 'P0001';

    END;



    ------------------------------------------------------------------

    -- Payload integrity validation

    ------------------------------------------------------------------

    IF NOT (

        v_payload ? 'actionable_id'

        AND v_payload ? 'request_id'

        AND v_payload ? 'completed_by'

    ) THEN

        RAISE EXCEPTION

            'Invalid actionable binding payload for "%".',

            p_actionable_name

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Validate request ownership

    ------------------------------------------------------------------

    IF (v_payload ->> 'request_id')::bigint <> p_request_id THEN

        RAISE EXCEPTION

            'Operation denied. Actionable "%" is not bound to request %.',

            p_actionable_name,

            p_request_id

            USING ERRCODE = 'P0001';

    END IF;



    RETURN;

END;

$function$