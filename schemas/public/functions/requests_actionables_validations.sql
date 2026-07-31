CREATE OR REPLACE FUNCTION public.requests_actionables_validations()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_json              jsonb;

    v_request_id        bigint;

    v_module            text;

    v_status            text;



    v_action_name       text;

    v_action_category   text;

    v_action_def        jsonb;

    v_allowed           boolean;

BEGIN

    ------------------------------------------------------------------

    -- 0) MANDATORY FIELD GUARDS

    ------------------------------------------------------------------

    IF NEW.actionable_name IS NULL THEN

        RAISE EXCEPTION 'Γ¥î actionable_name is mandatory.';

    END IF;



    IF NEW.actionable_category IS NULL THEN

        RAISE EXCEPTION 'Γ¥î actionable_category is mandatory.';

    END IF;



    IF NEW.request_subject IS NULL THEN

        RAISE EXCEPTION 'Γ¥î request_subject is mandatory.';

    END IF;



    v_action_name     := trim(NEW.actionable_name);

    v_action_category := initcap(lower(trim(NEW.actionable_category)));



    ------------------------------------------------------------------

    -- 1) IMMUTABLE IDENTITY (UPDATE ONLY)

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN

        IF NEW.actionable_name         IS DISTINCT FROM OLD.actionable_name

        OR NEW.actionable_category     IS DISTINCT FROM OLD.actionable_category

        OR NEW.request_subject         IS DISTINCT FROM OLD.request_subject

        THEN

            RAISE EXCEPTION

                'Γ¥î Actionable identity fields are immutable.';

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- 2) FETCH REQUEST CONTEXT

    ------------------------------------------------------------------

    SELECT r.in_record_id, r.module, r.status

      INTO v_request_id, v_module, v_status

      FROM public.requests r

     WHERE r.in_record_id = NEW.request_subject;



    IF v_request_id IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Invalid request_subject "%".',

            NEW.request_subject;

    END IF;



    v_module := initcap(lower(trim(v_module)));

    v_status := initcap(lower(trim(v_status)));



    ------------------------------------------------------------------

    -- 3) LOAD AUTHORITATIVE METADATA

    ------------------------------------------------------------------

    SELECT actionable_config

      INTO v_json

      FROM public.actionables_execution_metadata

     ORDER BY in_record_id DESC

     LIMIT 1;



    IF v_json IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Workflow metadata not configured.';

    END IF;



    ------------------------------------------------------------------

    -- 4) ACTIONABLE EXISTS IN METADATA

    ------------------------------------------------------------------

    v_action_def :=

        v_json -> 'Request'

               -> 'Actionable'

               -> v_action_name;



    IF v_action_def IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Unknown actionable "%".',

            v_action_name;

    END IF;



    ------------------------------------------------------------------

    -- 5) CATEGORY VALIDATION

    ------------------------------------------------------------------

    IF initcap(lower(v_action_def ->> 'Category')) <> v_action_category THEN

        RAISE EXCEPTION

            'Γ¥î Actionable "%" does not belong to category "%".',

            v_action_name, v_action_category;

    END IF;



    ------------------------------------------------------------------

    -- 6) INSERT-ONLY AUTHORIZATION (METADATA-DRIVEN)

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        SELECT EXISTS (

            SELECT 1

            FROM jsonb_array_elements(v_action_def -> 'Allowed On') allow

            WHERE initcap(lower(allow ->> 'Module')) = v_module

              AND EXISTS (

                    SELECT 1

                    FROM jsonb_array_elements_text(allow -> 'Statuses') s(status)

                    WHERE initcap(lower(s.status)) = v_status

              )

        )

        INTO v_allowed;



        IF NOT v_allowed THEN

            RAISE EXCEPTION

                'Γ¥î Actionable "%" is not allowed for module "%" in status "%".',

                v_action_name, v_module, v_status;

        END IF;









    END IF;



    RETURN NEW;

END;

$function$