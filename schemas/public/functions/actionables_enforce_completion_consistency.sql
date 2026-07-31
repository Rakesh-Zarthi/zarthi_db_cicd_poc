CREATE OR REPLACE FUNCTION public.actionables_enforce_completion_consistency()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_user_uuid uuid;

    v_user_id   bigint;

BEGIN

    ------------------------------------------------------------------

    -- If status = Complete ΓåÆ ensure completed_by + completion_time exist

    ------------------------------------------------------------------

    IF NEW.actionable_status::text = 'Complete' THEN



        ------------------------------------------------------------------

        -- Resolve session user (app.CURRENT_USER_ID) ΓåÆ users.in_record_id

        ------------------------------------------------------------------

        BEGIN

            v_user_uuid := current_setting('app.CURRENT_USER_ID', true)::uuid;

        EXCEPTION WHEN others THEN

            RAISE EXCEPTION

                '[ACTIONABLES][ERROR] Invalid app.CURRENT_USER_ID (expected UUID).';

        END;



        IF v_user_uuid IS NULL THEN

            RAISE EXCEPTION

                '[ACTIONABLES][ERROR] app.CURRENT_USER_ID is not set.';

        END IF;



        SELECT u.in_record_id

          INTO v_user_id

          FROM public.users u

         WHERE u.user_id = v_user_uuid;



        IF v_user_id IS NULL THEN

            RAISE EXCEPTION

                '[ACTIONABLES][ERROR] No public.users row found for app.CURRENT_USER_ID=%',

                v_user_uuid;

        END IF;



        ------------------------------------------------------------------

        -- Apply completion fields

        ------------------------------------------------------------------

        IF NEW.completed_by IS NULL THEN

            NEW.completed_by := v_user_id;   -- Γ£à session executor

        END IF;



        IF NEW.actionable_completion_time IS NULL THEN

            NEW.actionable_completion_time := now();

        END IF;



    ------------------------------------------------------------------

    -- If not Complete ΓåÆ enforce NULL completion fields

    ------------------------------------------------------------------

    ELSE

        NEW.completed_by := NULL;

        NEW.actionable_completion_time := NULL;

    END IF;



    RETURN NEW;

END;

$function$