CREATE OR REPLACE FUNCTION public.tg_validate_handover_new_owner()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    ------------------------------------------------------------------

    -- Validate only when NEW owner is provided

    ------------------------------------------------------------------

    IF NEW.ref_users_in_record_id_requests_owner_new IS NOT NULL THEN



        IF NEW.ref_requests_in_record_id IS NULL THEN

            RAISE EXCEPTION

                'Handover validation failed: ref_requests_in_record_id cannot be NULL';

        END IF;



        PERFORM public.fn_validate_request_owner_eligibility(

            NEW.ref_requests_in_record_id,

            NEW.ref_users_in_record_id_requests_owner_new

        );

    END IF;



    RETURN NEW;

END;

$function$