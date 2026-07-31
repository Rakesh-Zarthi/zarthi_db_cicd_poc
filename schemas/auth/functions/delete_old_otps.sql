CREATE OR REPLACE FUNCTION auth.delete_old_otps()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN



    DELETE FROM auth.user_otps

    WHERE ref_users_email_address = NEW.ref_users_email_address;



    RETURN NEW;



END;

$function$