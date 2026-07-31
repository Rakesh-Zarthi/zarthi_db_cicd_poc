CREATE OR REPLACE FUNCTION public.tg_validate_root_parent_is_problem()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

BEGIN

    PERFORM 1

    FROM public.requests r

    WHERE r.in_record_id = NEW.root_parent

      AND r.module = 'Problem';



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid root_parent %. Root parent must reference a Problem request.',

            NEW.root_parent;

    END IF;



    RETURN NEW;

END;

$function$