CREATE OR REPLACE FUNCTION public.etl_sync_users_account_fields()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- INSERT case

    IF TG_OP = 'INSERT' THEN

        -- Prefer user_account if present

        IF NEW.user_account IS NOT NULL THEN

            NEW.ref_accounts_in_record_id := NEW.user_account;

        ELSIF NEW.ref_accounts_in_record_id IS NOT NULL THEN

            NEW.user_account := NEW.ref_accounts_in_record_id;

        END IF;



        RETURN NEW;

    END IF;



    -- UPDATE case



    -- Case 1: user_account changed ΓåÆ sync ref_accounts_in_record_id

    IF NEW.user_account IS DISTINCT FROM OLD.user_account THEN

        IF NEW.ref_accounts_in_record_id IS DISTINCT FROM NEW.user_account THEN

            NEW.ref_accounts_in_record_id := NEW.user_account;

        END IF;

    END IF;



    -- Case 2: ref_accounts_in_record_id changed ΓåÆ sync user_account

    IF NEW.ref_accounts_in_record_id IS DISTINCT FROM OLD.ref_accounts_in_record_id THEN

        IF NEW.user_account IS DISTINCT FROM NEW.ref_accounts_in_record_id THEN

            NEW.user_account := NEW.ref_accounts_in_record_id;

        END IF;

    END IF;



    RETURN NEW;

END;

$function$