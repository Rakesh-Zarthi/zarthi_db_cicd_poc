CREATE OR REPLACE FUNCTION public.app_current_user_is_valid_policy_helper()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$

SELECT EXISTS (

    SELECT 1

    FROM public.users u

    WHERE u.user_id =

          current_setting('app.CURRENT_USER_ID', true)::uuid

);

$function$