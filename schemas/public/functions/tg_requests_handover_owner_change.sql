CREATE OR REPLACE FUNCTION public.tg_requests_handover_owner_change()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    ------------------------------------------------------------------

    -- Fire ONLY when:

    -- 1) status becomes 'Approved'

    -- 2) new owner is present

    -- 3) owner actually changes

    ------------------------------------------------------------------

    IF NEW.status = 'Approve'

       AND NEW.ref_users_in_record_id_new IS NOT NULL

       AND (

            TG_OP = 'INSERT'

            OR NEW.status IS DISTINCT FROM OLD.status

            OR NEW.ref_users_in_record_id_new IS DISTINCT FROM OLD.ref_users_in_record_id_new

       )

    THEN

        ------------------------------------------------------------------

        -- Update request owner

        -- All validations & cascades handled by existing triggers

        ------------------------------------------------------------------

        UPDATE public.requests r

           SET owner = NEW.ref_users_in_record_id_new

         WHERE r.in_record_id = NEW.ref_requests_in_record_id

           AND r.owner IS DISTINCT FROM NEW.ref_users_in_record_id_new;



        RAISE NOTICE

            'Γ£à Request % owner transferred via handover: % ΓåÆ %',

            NEW.ref_requests_in_record_id,

            NEW.ref_users_in_record_id_current,

            NEW.ref_users_in_record_id_new;

    END IF;



    RETURN NEW;

END;

$function$