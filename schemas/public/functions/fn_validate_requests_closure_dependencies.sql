CREATE OR REPLACE FUNCTION public.fn_validate_requests_closure_dependencies()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_status text := lower(NEW.status);

BEGIN

    ----------------------------------------------------------------

    -- Guard: Only validate on Close transition

    ----------------------------------------------------------------

    IF v_status NOT IN ('close') THEN

        RETURN NEW;

    END IF;



    ----------------------------------------------------------------

    -- 1. Validate: No open actionables on self or descendants

    ----------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.requests_hierarchy rh_self

        JOIN public.requests_actionables_open rao

          ON rao.requests_in_record_id = ANY (

                 ARRAY[NEW.in_record_id] || rh_self.all_children

             )

        WHERE rh_self.request_id = NEW.in_record_id

          AND rao.open_actionables_count > 0

    ) THEN

        RAISE EXCEPTION

            'Γ¥î Cannot close request "%" ΓÇö open actionables exist on this request or its dependents.',

            NEW.in_record_name;

    END IF;



    ----------------------------------------------------------------

    -- 2. Validate: All descendants are already closed

    ----------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.requests_hierarchy rh_self

        JOIN public.requests r

          ON r.in_record_id = ANY (rh_self.all_children)

        WHERE rh_self.request_id = NEW.in_record_id

          AND lower(COALESCE(r.status::text, '')) NOT IN ('close')

    ) THEN

        RAISE EXCEPTION

            'Γ¥î Cannot close request "%" ΓÇö one or more dependent requests are not closed.',

            NEW.in_record_name;

    END IF;





    ----------------------------------------------------------------

    -- 3. Validate: No active usage records exist

    ----------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.usage u

        WHERE u.ref_requests_in_record_id = NEW.in_record_id

          AND u.status IN (

                'Commercial Approval Pending',

                'Delivery In Progress',

                'Awaiting Approval'

          )

    ) THEN

        RAISE EXCEPTION

            'Γ¥î Cannot close request "%" ΓÇö active usage records exist.',

            NEW.in_record_name;

    END IF;



    ----------------------------------------------------------------

    -- Success

    ----------------------------------------------------------------

    RAISE NOTICE

        'Γ£à Request "%" can be safely closed ΓÇö all dependent requests are closed and no open actionables exist.',

        NEW.in_record_name;



    RETURN NEW;

END;

$function$