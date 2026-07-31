CREATE OR REPLACE FUNCTION public.etl_sync_users_external_user_ref()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- =====================

    -- INSERT HANDLING

    -- =====================

    IF TG_OP = 'INSERT' THEN

        -- Prefer in_ref_users_in_record_id

        IF NEW.in_ref_users_in_record_id IS NOT NULL THEN

            NEW.ref_users_in_record_id := NEW.in_ref_users_in_record_id;

        ELSIF NEW.ref_users_in_record_id IS NOT NULL THEN

            NEW.in_ref_users_in_record_id := NEW.ref_users_in_record_id;

        END IF;



        RETURN NEW;

    END IF;



    -- =====================

    -- UPDATE HANDLING

    -- =====================



    -- Case 1: in_ref_users changed ΓåÆ sync ref_users

    IF NEW.in_ref_users_in_record_id IS DISTINCT FROM OLD.in_ref_users_in_record_id THEN

        IF NEW.ref_users_in_record_id IS DISTINCT FROM NEW.in_ref_users_in_record_id THEN

            NEW.ref_users_in_record_id := NEW.in_ref_users_in_record_id;

        END IF;

    END IF;



    -- Case 2: ref_users changed ΓåÆ sync in_ref_users

    IF NEW.ref_users_in_record_id IS DISTINCT FROM OLD.ref_users_in_record_id THEN

        IF NEW.in_ref_users_in_record_id IS DISTINCT FROM NEW.ref_users_in_record_id THEN

            NEW.in_ref_users_in_record_id := NEW.ref_users_in_record_id;

        END IF;

    END IF;



    RETURN NEW;

END;

$function$