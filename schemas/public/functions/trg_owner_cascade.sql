CREATE OR REPLACE FUNCTION public.trg_owner_cascade()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    ------------------------------------------------------------------

    -- ABSOLUTE RULE: never cascade on INSERT

    ------------------------------------------------------------------

    IF TG_OP <> 'UPDATE' THEN

        RETURN NULL;

    END IF;



    ------------------------------------------------------------------

    -- Skip if owner unchanged

    ------------------------------------------------------------------

    IF NEW.owner IS NOT DISTINCT FROM OLD.owner THEN

        RETURN NULL;

    END IF;



    ------------------------------------------------------------------

    -- Safety: PK must exist

    ------------------------------------------------------------------

    IF NEW.in_record_id IS NULL THEN

        RAISE EXCEPTION

            'FATAL: owner cascade called without request id';

    END IF;



    ------------------------------------------------------------------

    -- Cascade

    ------------------------------------------------------------------

    UPDATE public.requests r

    SET owner = NEW.owner

    WHERE r.in_record_id <> NEW.in_record_id

      AND r.in_record_id IN (

          SELECT ref_requests_record_id

          FROM public.requests_services

          WHERE immediate_parent = NEW.in_record_id

      )

      AND r.owner IS DISTINCT FROM NEW.owner;



    ------------------------------------------------------------------

    -- Correct log

    ------------------------------------------------------------------

    RAISE NOTICE

        '≡ƒöä Owner cascade complete for Request %, owner changed % ΓåÆ %',

        NEW.in_record_id,

        OLD.owner,

        NEW.owner;



    RETURN NULL;

END;

$function$