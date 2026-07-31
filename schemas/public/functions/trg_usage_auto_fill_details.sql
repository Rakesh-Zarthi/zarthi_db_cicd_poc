CREATE OR REPLACE FUNCTION public.trg_usage_auto_fill_details()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$



DECLARE

    v_req_module text;

BEGIN



    ------------------------------------------------------------------

    -- Apply validation only for Roles requests

    ------------------------------------------------------------------

    SELECT initcap(lower(trim(r.module)))

    INTO v_req_module

    FROM public.requests r

    WHERE r.in_record_id = NEW.ref_requests_in_record_id;



    IF COALESCE(v_req_module, '') <> 'Roles' THEN

        RETURN NEW;

    END IF;





    ------------------------------------------------------------------

    -- Roles-specific validation starts here

    ------------------------------------------------------------------



    IF TG_OP = 'UPDATE'

       AND OLD.status IN (

            'Billed',

            'Cancelled',

            'Approved',

            'Rejected',

            'Delivered'

       )

       AND (

            OLD.ref_requests_in_record_id

                IS DISTINCT FROM NEW.ref_requests_in_record_id



            OR OLD.ref_users_in_record_id_consumer

                IS DISTINCT FROM NEW.ref_users_in_record_id_consumer



            OR OLD.ref_users_in_record_id_customer

                IS DISTINCT FROM NEW.ref_users_in_record_id_customer



            OR OLD.ref_users_in_record_id_owner

                IS DISTINCT FROM NEW.ref_users_in_record_id_owner

       )

    THEN

        RAISE EXCEPTION

            'Critical ownership/request fields cannot be modified for Roles usage record % when status is %.',

            OLD.in_record_id,

            OLD.status;

    END IF;



    ------------------------------------------------------------------

    -- Customer Name

    ------------------------------------------------------------------

    SELECT u.gen_full_name

    INTO NEW.customer_name_bill_to

    FROM public.users u

    WHERE u.in_record_id = NEW.ref_users_in_record_id_customer;



    ------------------------------------------------------------------

    -- Consumer Name

    ------------------------------------------------------------------

    SELECT u.gen_full_name

    INTO NEW.consumer

    FROM public.users u

    WHERE u.in_record_id = NEW.ref_users_in_record_id_consumer;



    ------------------------------------------------------------------

    -- Solution Owner Name

    ------------------------------------------------------------------

    SELECT u.gen_full_name

    INTO NEW.solution_owner

    FROM public.users u

    WHERE u.in_record_id = NEW.ref_users_in_record_id_owner;



    ------------------------------------------------------------------

    -- Solution Owner Practice

    ------------------------------------------------------------------

    SELECT p.practice_name_corporate_unit

    INTO NEW.solution_owner_practice

    FROM public.users_internal ui



    INNER JOIN public.practices p

        ON p.in_record_id = ui.ref_practice_in_record_id



    WHERE ui.in_ref_users_in_record_id =

          NEW.ref_users_in_record_id_owner;



    RETURN NEW;



END;

$function$