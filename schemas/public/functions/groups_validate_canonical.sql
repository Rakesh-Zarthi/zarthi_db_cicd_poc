CREATE OR REPLACE FUNCTION public.groups_validate_canonical()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    IF TG_OP = 'INSERT' THEN

        -- ≡ƒöÆ Authorize using transaction binding ONLY

        PERFORM public.require_completed_actionable(

            NEW.ref_requests_in_record_id_group_owner,

            'Collaborations',

            'Create Group'

        );

    END IF;



    RETURN NEW;

END;

$function$