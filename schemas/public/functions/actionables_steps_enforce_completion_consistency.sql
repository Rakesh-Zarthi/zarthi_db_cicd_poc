CREATE OR REPLACE FUNCTION public.actionables_steps_enforce_completion_consistency()
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

    IF NEW.status::text = 'Complete' THEN



        ------------------------------------------------------------------

        -- If completed_by not provided ΓåÆ resolve from session CURRENT_USER_ID

        -- (SYNC-SAFE: if sync provides completed_by, we won't require session)

        ------------------------------------------------------------------

        IF NEW.ref_users_in_record_id_completed_by IS NULL THEN



            BEGIN

                v_user_uuid := NULLIF(current_setting('app.CURRENT_USER_ID', true), '')::uuid;

            EXCEPTION

                WHEN invalid_text_representation THEN

                    RAISE EXCEPTION

                        '[ACTIONABLE_STEPS][ERROR] Invalid app.CURRENT_USER_ID (expected UUID).';

            END;



            IF v_user_uuid IS NULL THEN

                RAISE EXCEPTION

                    '[ACTIONABLE_STEPS][ERROR] app.CURRENT_USER_ID is not set.';

            END IF;



            SELECT u.in_record_id

              INTO v_user_id

              FROM public.users u

             WHERE u.user_id = v_user_uuid;



            IF v_user_id IS NULL THEN

                RAISE EXCEPTION

                    '[ACTIONABLE_STEPS][ERROR] No public.users row found for app.CURRENT_USER_ID=%',

                    v_user_uuid;

            END IF;



            NEW.ref_users_in_record_id_completed_by := v_user_id;  -- executor user

        END IF;



        ------------------------------------------------------------------

        -- Apply completion timestamp

        ------------------------------------------------------------------

        IF NEW.step_completion_time IS NULL THEN

            NEW.step_completion_time := now();

        END IF;



    ------------------------------------------------------------------

    -- If not Complete ΓåÆ enforce NULL completion fields

    ------------------------------------------------------------------

    ELSE

        NEW.ref_users_in_record_id_completed_by := NULL;

        NEW.step_completion_time := NULL;

    END IF;



    RETURN NEW;

END;

$function$