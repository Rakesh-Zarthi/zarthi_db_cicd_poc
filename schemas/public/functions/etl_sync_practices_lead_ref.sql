CREATE OR REPLACE FUNCTION public.etl_sync_practices_lead_ref()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- =====================

    -- INSERT HANDLING

    -- =====================

    IF TG_OP = 'INSERT' THEN

        -- Prefer corporate_lead

        IF NEW.corporate_lead IS NOT NULL THEN

            NEW.ref_users_in_record_id_practice_lead := NEW.corporate_lead;

        ELSIF NEW.ref_users_in_record_id_practice_lead IS NOT NULL THEN

            NEW.corporate_lead := NEW.ref_users_in_record_id_practice_lead;

        END IF;



        RETURN NEW;

    END IF;



    -- =====================

    -- UPDATE HANDLING

    -- =====================



    -- Case 1: corporate_lead changed ΓåÆ sync mirror

    IF NEW.corporate_lead IS DISTINCT FROM OLD.corporate_lead THEN

        IF NEW.ref_users_in_record_id_practice_lead IS DISTINCT FROM NEW.corporate_lead THEN

            NEW.ref_users_in_record_id_practice_lead := NEW.corporate_lead;

        END IF;

    END IF;



    -- Case 2: mirror changed ΓåÆ sync back

    IF NEW.ref_users_in_record_id_practice_lead IS DISTINCT FROM OLD.ref_users_in_record_id_practice_lead THEN

        IF NEW.corporate_lead IS DISTINCT FROM NEW.ref_users_in_record_id_practice_lead THEN

            NEW.corporate_lead := NEW.ref_users_in_record_id_practice_lead;

        END IF;

    END IF;



    RETURN NEW;

END;

$function$