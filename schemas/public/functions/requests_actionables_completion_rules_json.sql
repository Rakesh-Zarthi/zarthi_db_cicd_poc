CREATE OR REPLACE FUNCTION public.requests_actionables_completion_rules_json()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_action_name   text;

    v_metadata      jsonb;

    v_rules         jsonb;

    v_missing       text[];

BEGIN

    ------------------------------------------------------------------

    -- 1) Fire ONLY when step transitions to Complete

    ------------------------------------------------------------------

    IF NEW.status::text <> 'Complete'

       OR OLD.status::text = 'Complete' THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 2) Load parent actionable + latest metadata

    ------------------------------------------------------------------

    SELECT a.actionable_name,

           m.actionable_config

      INTO v_action_name, v_metadata

      FROM public.actionables a

      JOIN LATERAL (

           SELECT actionable_config

             FROM public.actionables_execution_metadata

            ORDER BY in_record_id DESC

            LIMIT 1

      ) m ON true

     WHERE a.in_record_id = NEW.ref_actionables_in_record_id;



    IF v_metadata IS NULL THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 3) Extract completion rules (if any)

    ------------------------------------------------------------------

    v_rules :=

        v_metadata

            -> 'Request'

            -> 'Actionable'

            -> v_action_name

            -> 'Completion Rules';



    IF v_rules IS NULL THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 4) Enforce only for configured step

    ------------------------------------------------------------------

    IF (v_rules ->> 'Step')::int <> NEW.step_no THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 5) Validate required fields dynamically

    ------------------------------------------------------------------

    SELECT array_agg(f)

      INTO v_missing

      FROM jsonb_array_elements_text(v_rules -> 'Required Fields') f

      WHERE (to_jsonb(

            (SELECT a.*

               FROM public.actionables a

              WHERE a.in_record_id = NEW.ref_actionables_in_record_id)

           ) ->> f) IS NULL;



    IF array_length(v_missing, 1) IS NOT NULL THEN

        RAISE EXCEPTION

            'Γ¥î Cannot complete step %. Missing mandatory fields: %',

            NEW.step_no,

            array_to_string(v_missing, ', ');

    END IF;



    RETURN NEW;

END;

$function$