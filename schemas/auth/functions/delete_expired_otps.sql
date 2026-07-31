CREATE OR REPLACE FUNCTION auth.delete_expired_otps()
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_deleted_count bigint;

BEGIN

    DELETE FROM auth.user_otps

    WHERE created_time < CURRENT_TIMESTAMP - INTERVAL '7 days';



    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;



    RETURN v_deleted_count;

END;

$function$