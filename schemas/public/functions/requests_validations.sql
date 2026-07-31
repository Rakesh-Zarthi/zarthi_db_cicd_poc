CREATE OR REPLACE FUNCTION public.requests_validations()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_json              jsonb;

    v_module_node       jsonb;

    v_status_node       jsonb;

    v_old_status        text;

    v_new_status        text;

    v_module            text;

    v_allowed_next      boolean;

    v_default_status    text;

BEGIN

    ------------------------------------------------------------------

    -- 0) NORMALIZATION & MANDATORY GUARDS

    ------------------------------------------------------------------

    IF NEW.module IS NULL THEN

        RAISE EXCEPTION 'Γ¥î Module is mandatory.';

    END IF;



    NEW.module := initcap(lower(trim(NEW.module)));



    IF NEW.status IS NOT NULL THEN

        NEW.status := initcap(lower(trim(NEW.status)));

    END IF;



    v_module     := NEW.module;

    v_new_status := NEW.status;



    IF TG_OP = 'UPDATE' THEN

        v_old_status := initcap(lower(trim(OLD.status)));

    END IF;



    ------------------------------------------------------------------

    -- 1) LOAD AUTHORITATIVE METADATA

    ------------------------------------------------------------------

    SELECT actionable_config

      INTO v_json

      FROM public.actionables_execution_metadata

     ORDER BY in_record_id DESC

     LIMIT 1;



    IF v_json IS NULL THEN

        RAISE EXCEPTION 'Γ¥î Request workflow metadata not configured.';

    END IF;



    ------------------------------------------------------------------

    -- 2) MODULE VALIDATION (JSON-DRIVEN)

    ------------------------------------------------------------------

    v_module_node :=

        v_json -> 'Request'

               -> 'Sub Request Type'

               -> v_module;



    IF v_module_node IS NULL THEN

        RAISE EXCEPTION 'Γ¥î Invalid request module "%".', v_module;

    END IF;



    ------------------------------------------------------------------

    -- 3) REQUEST DEPENDENCY RULE

    ------------------------------------------------------------------

    IF v_module = 'Problem'

       AND NEW.request_dependency <> 'Standalone' THEN

        RAISE EXCEPTION 'Γ¥î Problem requests must be Standalone.';

    END IF;



    IF v_module IN ('Services', 'Staffing','Roles')

       AND NEW.request_dependency <> 'Dependent' THEN

        RAISE EXCEPTION 'Γ¥î Services/Staffing requests must be Dependent.';

    END IF;



    ------------------------------------------------------------------

    -- 4) OWNER RULE

    ------------------------------------------------------------------

    IF v_module IN ('Problem', 'Staffing')

       AND NEW.owner IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Owner is mandatory for module "%".', v_module;

    END IF;



    ------------------------------------------------------------------

------------------------------------------------------------------

-- 5) DEFAULT STATUS (INSERT ONLY, METADATA-FIRST)

------------------------------------------------------------------

IF TG_OP = 'INSERT' THEN



    -- 1) explicit default from metadata (recommended)

    v_default_status := v_module_node ->> 'Default Status';



    -- 2) otherwise choose sensible defaults

    IF v_default_status IS NULL THEN

        IF (v_module_node -> 'Sub Request Status' ? 'Backlog') THEN

            v_default_status := 'Backlog';

        ELSIF (v_module_node -> 'Sub Request Status' ? 'Open') THEN

            v_default_status := 'Open';

        ELSE

            -- 3) fallback: pick any configured status (NOT alphabetical)

            SELECT s.status

              INTO v_default_status

              FROM jsonb_object_keys(v_module_node -> 'Sub Request Status') AS s(status)

              LIMIT 1;

        END IF;

    END IF;



    IF v_default_status IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î No status configured for module "%".', v_module;

    END IF;



    NEW.status := COALESCE(NULLIF(v_new_status, ''), v_default_status);

    v_new_status := NEW.status;

END IF;





    ------------------------------------------------------------------

    -- 6) STATUS EXISTS FOR MODULE

    ------------------------------------------------------------------

    v_status_node :=

        v_module_node

        -> 'Sub Request Status'

        -> v_new_status;



    IF v_status_node IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Status "%" not allowed for module "%".',

            v_new_status, v_module;

    END IF;



    ------------------------------------------------------------------

    -- 7) TERMINAL IMMUTABILITY

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE'

       AND v_old_status = 'Close'

       AND v_new_status <> 'Close'

    THEN

        RAISE EXCEPTION

            'Γ¥î Request % is already Close and cannot transition.',

            OLD.in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- 8) METADATA-DRIVEN STATUS TRANSITION

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE'

       AND v_old_status IS DISTINCT FROM v_new_status

       AND v_old_status <> 'Close'

    THEN

        SELECT EXISTS (

            SELECT 1

            FROM jsonb_array_elements_text(

                v_module_node

                -> 'Sub Request Status'

                -> v_old_status

                -> 'Next Status'

            ) AS s(next_status)

            WHERE s.next_status = v_new_status

        )

        INTO v_allowed_next;



        IF NOT v_allowed_next THEN

            RAISE EXCEPTION

                'Γ¥î Invalid status transition "%" ΓåÆ "%" for module "%".',

                v_old_status, v_new_status, v_module;

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- 9) FIELD IMMUTABILITY RULES

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN



        IF NEW.summary IS DISTINCT FROM OLD.summary THEN

            RAISE EXCEPTION

                'Γ¥î Summary is immutable after creation.';

        END IF;



        IF NEW.description IS DISTINCT FROM OLD.description THEN



            IF v_module = 'Problem'

               AND v_new_status NOT IN ('Open', 'Pause')

            THEN

                RAISE EXCEPTION

                    'Γ¥î Problem description editable only in Open or Pause.';

            END IF;



            IF v_module IN ('Services', 'Staffing','Roles')

               AND v_new_status = 'Close'

            THEN

                RAISE EXCEPTION

                    'Γ¥î Description cannot be edited after Close.';

            END IF;

        END IF;

    END IF;



    RETURN NEW;

END;

$function$