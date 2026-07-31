CREATE OR REPLACE FUNCTION public.app_fn_broken_link_url(p_url text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_redirect_url text;

    v_actor uuid := '5c58b64f-e717-4c8c-a971-170acf7a45e7';

BEGIN



    ------------------------------------------------------------------

    -- Check if URL exists

    ------------------------------------------------------------------

    SELECT redirection_url

    INTO v_redirect_url

    FROM public.broken_links_url

    WHERE broken_link_url = p_url;



    ------------------------------------------------------------------

    -- If URL exists ΓåÆ update count and return output

    ------------------------------------------------------------------

    IF FOUND THEN



        UPDATE public.broken_links_url

        SET

            count = COALESCE(count, 0) + 1,

            in_ref_modified_user_uuid = v_actor,

            in_modified_time = clock_timestamp(),

            hit_date = CURRENT_DATE

        WHERE broken_link_url = p_url

        RETURNING redirection_url

        INTO v_redirect_url;



        RETURN COALESCE(v_redirect_url, '');



    ------------------------------------------------------------------

    -- If URL does not exist ΓåÆ try insert

    ------------------------------------------------------------------

    ELSE



        INSERT INTO public.broken_links_url (

            broken_link_url,

            count,

            hit_date,

            in_ref_added_user_uuid,

            in_ref_modified_user_uuid,

            in_added_time,

            in_modified_time

        )

        VALUES (

            p_url,

            1,

            CURRENT_DATE,

            v_actor,

            v_actor,

            clock_timestamp(),

            clock_timestamp()

        )



        ------------------------------------------------------------------

        -- Handles concurrent insert of same URL

        ------------------------------------------------------------------

        ON CONFLICT (broken_link_url)

        DO UPDATE

        SET

            count = COALESCE(broken_links_url.count, 0) + 1,

            in_ref_modified_user_uuid = v_actor,

            in_modified_time = clock_timestamp(),

            hit_date = CURRENT_DATE



        RETURNING redirection_url

        INTO v_redirect_url;



        RETURN COALESCE(v_redirect_url, '');



    END IF;



END;

$function$