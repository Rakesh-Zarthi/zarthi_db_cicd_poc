CREATE OR REPLACE FUNCTION public.global_requests_validations()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_new jsonb := to_jsonb(NEW);

BEGIN

    -- allow system writes

    IF current_setting('app.system_write', true) = 'true' THEN

        RETURN NEW;

    END IF;



    -- prevent moving record to another request

    IF TG_OP = 'UPDATE' AND (v_new ? 'ref_requests_record_id') THEN

        IF NEW.ref_requests_record_id IS DISTINCT FROM OLD.ref_requests_record_id THEN

            RAISE EXCEPTION 'ref_requests_record_id cannot be changed';

        END IF;

    END IF;



    RETURN NEW;

END;

$function$