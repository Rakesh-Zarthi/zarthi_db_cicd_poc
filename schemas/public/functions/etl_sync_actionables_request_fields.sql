CREATE OR REPLACE FUNCTION public.etl_sync_actionables_request_fields()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- INSERT

    IF TG_OP = 'INSERT' THEN

        IF NEW.request_subject IS NOT NULL THEN

            NEW.ref_requests_in_record_id := NEW.request_subject;

        ELSIF NEW.ref_requests_in_record_id IS NOT NULL THEN

            NEW.request_subject := NEW.ref_requests_in_record_id;

        END IF;



        RETURN NEW;

    END IF;



    -- UPDATE



    -- request_subject changed

    IF NEW.request_subject IS DISTINCT FROM OLD.request_subject THEN

        IF NEW.ref_requests_in_record_id IS DISTINCT FROM NEW.request_subject THEN

            NEW.ref_requests_in_record_id := NEW.request_subject;

        END IF;

    END IF;



    -- ref_requests_in_record_id changed

    IF NEW.ref_requests_in_record_id IS DISTINCT FROM OLD.ref_requests_in_record_id THEN

        IF NEW.request_subject IS DISTINCT FROM NEW.ref_requests_in_record_id THEN

            NEW.request_subject := NEW.ref_requests_in_record_id;

        END IF;

    END IF;



    RETURN NEW;

END;

$function$