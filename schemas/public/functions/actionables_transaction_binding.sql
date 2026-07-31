CREATE OR REPLACE FUNCTION public.actionables_transaction_binding()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_key         text;

    v_payload     jsonb;

    v_json        jsonb;

    v_is_request  boolean;

    v_existing    text;

BEGIN

    ------------------------------------------------------------------

    -- Bind ONLY on transition ΓåÆ Complete

    ------------------------------------------------------------------

    IF TG_OP <> 'UPDATE'

       OR NEW.actionable_status IS DISTINCT FROM 'Complete'

       OR OLD.actionable_status = 'Complete'

    THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Mandatory completion fields

    ------------------------------------------------------------------

    IF NEW.completed_by IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Cannot bind actionable %. completed_by is NULL.',

            NEW.in_record_id

            USING ERRCODE = 'P0001';

    END IF;



    IF NEW.actionable_completion_time IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Cannot bind actionable %. completion_time is NULL.',

            NEW.in_record_id

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Load authoritative metadata

    ------------------------------------------------------------------

    SELECT actionable_config

      INTO v_json

      FROM public.actionables_execution_metadata

     ORDER BY in_record_id DESC

     LIMIT 1;



    IF v_json IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Workflow metadata not configured.'

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Determine actionable scope (Request vs Role)

    ------------------------------------------------------------------

    v_is_request :=

        (v_json -> 'Request' -> 'Actionable' -> NEW.actionable_name) IS NOT NULL;



    -- Skip Role.Actionable (no transactional binding)

    IF NOT v_is_request THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Request actionable requires request_subject

    ------------------------------------------------------------------

    IF NEW.request_subject IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Cannot bind request actionable %. request_subject is NULL.',

            NEW.in_record_id

            USING ERRCODE = 'P0001';

    END IF;



    ------------------------------------------------------------------

    -- Canonical binding key

    ------------------------------------------------------------------

    v_key :=

        public.cns_actionable_binding_key(

            NEW.actionable_category,

            NEW.actionable_name

        );



    ------------------------------------------------------------------

    -- Build payload

    ------------------------------------------------------------------

    v_payload :=

        jsonb_build_object(

            'actionable_id', NEW.in_record_id,

            'request_id',    NEW.request_subject,

            'completed_by',  NEW.completed_by,

            'completed_at',  NEW.actionable_completion_time

        );



    ------------------------------------------------------------------

    -- Idempotent binding (robust)

    -- Treat NULL and empty string as unbound

    ------------------------------------------------------------------

    v_existing := current_setting(v_key, true);



    IF v_existing IS NULL OR btrim(v_existing) = '' THEN

        PERFORM set_config(

            v_key,

            v_payload::text,

            true

        );

    END IF;



    RETURN NEW;

END;

$function$