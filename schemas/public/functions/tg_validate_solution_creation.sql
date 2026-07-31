CREATE OR REPLACE FUNCTION public.tg_validate_solution_creation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_child_module text;

BEGIN

    SELECT module

    INTO v_child_module

    FROM public.requests

    WHERE in_record_id = NEW.ref_requests_record_id;



    IF v_child_module IS NULL THEN

        RAISE EXCEPTION

            'Invalid child request id %',

            NEW.ref_requests_record_id;

    END IF;



    PERFORM public.fn_validate_solution_creation(

        NEW.immediate_parent,

        NEW.root_parent,

        v_child_module,

        NEW.ref_requests_record_id

    );



    RETURN NEW;

END;

$function$