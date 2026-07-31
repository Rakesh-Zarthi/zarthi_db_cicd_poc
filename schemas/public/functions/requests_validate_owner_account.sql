CREATE OR REPLACE FUNCTION public.requests_validate_owner_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

DECLARE

    v_user_account public.record_id;

    v_talent_status text;

BEGIN



    -- Allow NULL owner

    IF NEW.owner IS NULL THEN

        RETURN NEW;

    END IF;



    -- Fetch user info

    SELECT

        u.user_account,

        ui.talent_status

    INTO

        v_user_account,

        v_talent_status

    FROM public.users u

    LEFT JOIN public.users_internal ui

        ON ui.in_ref_users_in_record_id = u.in_record_id

    WHERE u.in_record_id = NEW.owner;



    -- User must exist

    IF v_user_account IS NULL THEN

        RAISE EXCEPTION

            'Invalid owner assignment: user % does not exist.',

            NEW.owner

            USING ERRCODE = '23503';

    END IF;



    -- Restrict ONLY account = 1 with invalid talent_status

    IF v_user_account = 1

    AND v_talent_status NOT IN (

        'Centizen',

        'New Bee',

        'Serving Notice Period/KT'

    )

    THEN

        RAISE EXCEPTION

            'Invalid owner assignment: internal user % with status "%" is not eligible.',

            NEW.owner,

            COALESCE(v_talent_status, 'NULL')

            USING ERRCODE = '23514';

    END IF;



    -- All other accounts allowed

    RETURN NEW;



END;

$function$