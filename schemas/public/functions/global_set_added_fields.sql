CREATE OR REPLACE FUNCTION public.global_set_added_fields()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_user_uuid uuid := current_setting('app.CURRENT_USER_ID', true)::uuid;

    v_new       jsonb := to_jsonb(NEW);

BEGIN

    ------------------------------------------------------------------

    -- Set added time (only if column exists)

    ------------------------------------------------------------------

    IF v_new ? 'in_added_time' THEN

        NEW.in_added_time :=

            COALESCE(NEW.in_added_time, CURRENT_TIMESTAMP);

    END IF;



    ------------------------------------------------------------------

    -- Set added user (only if column exists)

    ------------------------------------------------------------------

    IF v_new ? 'in_ref_added_user_uuid' THEN

        NEW.in_ref_added_user_uuid :=

            COALESCE(NEW.in_ref_added_user_uuid, v_user_uuid);

    END IF;



    ------------------------------------------------------------------

    -- Set modified time (only if column exists)

    ------------------------------------------------------------------

    IF v_new ? 'in_modified_time' THEN

        NEW.in_modified_time :=

            COALESCE(NEW.in_modified_time, NEW.in_added_time, CURRENT_TIMESTAMP);

    END IF;



    ------------------------------------------------------------------

    -- Set modified user (only if column exists)

    ------------------------------------------------------------------

    IF v_new ? 'in_ref_modified_user_uuid' THEN

        NEW.in_ref_modified_user_uuid :=

            COALESCE(NEW.in_ref_modified_user_uuid, v_user_uuid);

    END IF;



    RETURN NEW;

END;

$function$