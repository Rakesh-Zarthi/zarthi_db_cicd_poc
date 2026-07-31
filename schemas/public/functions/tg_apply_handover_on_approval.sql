CREATE OR REPLACE FUNCTION public.tg_apply_handover_on_approval()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    ------------------------------------------------------------------

    -- Fire ONLY when status transitions to 'Approved'

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE'

       AND NEW.status = 'Approve'

       AND OLD.status IS DISTINCT FROM NEW.status

    THEN

        ------------------------------------------------------------------

        -- Safety check: new owner must exist

        ------------------------------------------------------------------

        IF NEW.ref_users_in_record_id_requests_owner_new IS NULL THEN

            RAISE EXCEPTION

                'Γ¥î Cannot approve handover without new owner (request %)',

                NEW.ref_requests_in_record_id;

        END IF;



        ------------------------------------------------------------------

        -- Update request owner

        ------------------------------------------------------------------

        UPDATE public.requests r

           SET owner = NEW.ref_users_in_record_id_requests_owner_new

         WHERE r.in_record_id = NEW.ref_requests_in_record_id

           AND r.owner IS DISTINCT FROM NEW.ref_users_in_record_id_requests_owner_new;

    END IF;



    RETURN NEW;

END;

$function$