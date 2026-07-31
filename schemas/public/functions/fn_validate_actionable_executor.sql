CREATE OR REPLACE FUNCTION public.fn_validate_actionable_executor()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    IF NEW.actionable_status = 'Complete' THEN



        IF NEW.completed_by IS NULL THEN

            RAISE EXCEPTION

                'completed_by is required when completing an actionable'

                USING ERRCODE='P0001';

        END IF;



        ------------------------------------------------------------------

        -- NON-COLLABORATION: strict assignment enforcement

        ------------------------------------------------------------------

        IF NEW.actionable_category <> 'Collaborations'

           AND NEW.actionables_assigned_to IS NOT NULL

           AND NEW.completed_by <> NEW.actionables_assigned_to THEN

            RAISE EXCEPTION

                'User % is not authorized to complete this actionable',

                NEW.completed_by

                USING ERRCODE='P0001';

        END IF;



        -- Collaborations are authorized via CNS consume (group membership)



    END IF;



    RETURN NEW;

END;

$function$