CREATE OR REPLACE FUNCTION public.actionables_prevent_cycles()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_found_cycle boolean;

BEGIN

    -- Only validate when self-reference exists

    IF NEW.ref_actionables_in_record_id_previous IS NULL THEN

        RETURN NEW;

    END IF;



    /*

      Traverse chain upward:

      NEW.ref_actionables_in_record_id_previous ΓåÆ ... ΓåÆ root

      If we ever reach NEW.in_record_id ΓåÆ cycle exists

    */

    WITH RECURSIVE chain AS (

        SELECT

            a.in_record_id,

            a.ref_actionables_in_record_id_previous,

            1 AS depth

        FROM public.actionables a

        WHERE a.in_record_id = NEW.ref_actionables_in_record_id_previous



        UNION ALL



        SELECT

            p.in_record_id,

            p.ref_actionables_in_record_id_previous,

            c.depth + 1

        FROM public.actionables p

        JOIN chain c

          ON p.in_record_id = c.ref_actionables_in_record_id_previous

        WHERE c.depth < 100   -- recursion safety guard

    )

    SELECT TRUE

    INTO v_found_cycle

    FROM chain

    WHERE in_record_id = NEW.in_record_id

    LIMIT 1;



    IF v_found_cycle THEN

        RAISE EXCEPTION

            'Cycle detected in actionables chain: actionable % cannot reference itself indirectly',

            NEW.in_record_id;

    END IF;



    RETURN NEW;

END;

$function$