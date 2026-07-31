CREATE OR REPLACE FUNCTION public.users_0034_validate_users_assignment(p_user_id bigint, p_context text DEFAULT 'owner'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

DECLARE

    v_user_account public.record_id;

    v_talent_status text;

BEGIN

    --------------------------------------------------------------------

    -- Allow NULL

    --------------------------------------------------------------------

    IF p_user_id IS NULL THEN

        RETURN;

    END IF;



    --------------------------------------------------------------------

    -- Fetch user info (STRICT = must exist exactly once)

    --------------------------------------------------------------------

    BEGIN

        SELECT

            u.user_account,

            ui.talent_status

        INTO STRICT

            v_user_account,

            v_talent_status

        FROM public.users u

        LEFT JOIN public.users_internal ui

            ON ui.in_ref_users_in_record_id = u.in_record_id

        WHERE u.in_record_id = p_user_id;



    EXCEPTION

        WHEN NO_DATA_FOUND THEN

            RAISE EXCEPTION

                'Invalid % assignment: user % does not exist.',

                p_context, p_user_id

                USING ERRCODE = '23503';



        WHEN TOO_MANY_ROWS THEN

            RAISE EXCEPTION

                'Data integrity error: multiple user records found for %.',

                p_user_id

                USING ERRCODE = '23514';

    END;



    --------------------------------------------------------------------

    -- Internal account validation

    --------------------------------------------------------------------

    IF v_user_account = 1

    AND v_talent_status NOT IN (

        'Centizen',

        'New Bee',

        'Serving Notice Period/KT'

    )

    THEN

        RAISE EXCEPTION

            'Invalid % assignment: internal user % with status "%" is not eligible.',

            p_context,

            p_user_id,

            COALESCE(v_talent_status, 'NULL')

            USING ERRCODE = '23514';

    END IF;



END;

$function$