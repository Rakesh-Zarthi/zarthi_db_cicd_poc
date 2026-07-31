CREATE OR REPLACE FUNCTION public.role_actionables_validations()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$

DECLARE

    v_json            jsonb;

    v_action_def      jsonb;

    v_expected_cat    text;

    v_scope           text;  -- 'Request' or 'Role'

BEGIN

    ------------------------------------------------------------------

    -- 0) MANDATORY GUARDS

    ------------------------------------------------------------------

    IF NEW.actionable_name IS NULL THEN

        RAISE EXCEPTION 'Γ¥î actionable_name is mandatory.';

    END IF;



    IF NEW.actionable_category IS NULL THEN

        RAISE EXCEPTION 'Γ¥î actionable_category is mandatory.';

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

        RAISE EXCEPTION 'Γ¥î Workflow metadata not configured.';

    END IF;



    ------------------------------------------------------------------

    -- 2) RESOLVE ACTIONABLE FROM METADATA (SCOPE-AWARE)

    --    We DO NOT infer scope from category.

    --    We discover scope from metadata location.

    ------------------------------------------------------------------



    -- Try Request domain first

    v_action_def :=

        v_json

        -> 'Request'

        -> 'Actionable'

        -> NEW.actionable_name;



    IF v_action_def IS NOT NULL THEN

        v_scope := 'Request';



    ELSE

        -- Try Role domain

        v_action_def :=

            v_json

            -> 'Role'

            -> 'Actionable'

            -> NEW.actionable_name;



        IF v_action_def IS NOT NULL THEN

            v_scope := 'Role';

        END IF;

    END IF;



    IF v_action_def IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Unknown actionable "%".',

            NEW.actionable_name;

    END IF;



    ------------------------------------------------------------------

    -- 3) SCOPE ENFORCEMENT RULES

    ------------------------------------------------------------------



    IF v_scope = 'Request' THEN

        -- Request actionables MUST reference request_subject

        IF NEW.request_subject IS NULL THEN

            RAISE EXCEPTION

                'Γ¥î Request actionable "%" must reference request_subject.',

                NEW.actionable_name;

        END IF;



    ELSIF v_scope = 'Role' THEN

        -- Role actionables MUST NOT reference request_subject

        IF NEW.request_subject IS NOT NULL THEN

            RAISE EXCEPTION

                'Γ¥î Role actionable "%" must not reference request_subject.',

                NEW.actionable_name;

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- 4) AUTHORITATIVE CATEGORY VALIDATION

    ------------------------------------------------------------------



    v_expected_cat := v_action_def ->> 'Category';



    IF v_expected_cat IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Actionable "%" is misconfigured (missing Category in metadata).',

            NEW.actionable_name;

    END IF;



    IF trim(v_expected_cat) <> trim(NEW.actionable_category) THEN

        RAISE EXCEPTION

            'Γ¥î Actionable "%" belongs to category "%", not "%".',

            NEW.actionable_name,

            v_expected_cat,

            NEW.actionable_category;

    END IF;



    ------------------------------------------------------------------

    -- 5) IMMUTABILITY GUARDS

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN

        IF NEW.actionable_name     IS DISTINCT FROM OLD.actionable_name

        OR NEW.actionable_category IS DISTINCT FROM OLD.actionable_category

        OR NEW.created_by          IS DISTINCT FROM OLD.created_by

        THEN

            RAISE EXCEPTION

                'Γ¥î Actionable identity fields are immutable.';

        END IF;

    END IF;



    RETURN NEW;

END;

$function$