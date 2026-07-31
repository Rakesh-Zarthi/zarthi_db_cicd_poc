CREATE OR REPLACE FUNCTION auth.allow_login_only_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

DECLARE

    v_user_account public.record_id;

    v_node_permissions jsonb;  -- adjust type if different

BEGIN

    SELECT 

        u.user_account,

        u.node_permissions

    INTO 

        v_user_account,

        v_node_permissions

    FROM public.users u

    WHERE u.email_address = NEW.ref_users_email_address;



    -- User must exist

    IF v_user_account IS NULL THEN

        RAISE EXCEPTION 

        'Login denied: user "%" does not exist.',

        NEW.ref_users_email_address;

    END IF;



    -- Allow only specific accounts

    IF v_user_account NOT IN (1, 3987) THEN

        RAISE EXCEPTION 

        'Login denied: account "%" is not permitted to login.',

        v_user_account;

    END IF;



    -- node_permissions must not be NULL

    IF v_node_permissions IS NULL THEN

        RAISE EXCEPTION

        'Login denied: user "%" has no permissions assigned.',

        NEW.ref_users_email_address;

    END IF;



    RETURN NEW;

END;

$function$