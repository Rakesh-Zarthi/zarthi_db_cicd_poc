CREATE OR REPLACE FUNCTION public.app_current_app_is_valid_policy_helper()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$

SELECT EXISTS (

    SELECT 1

    FROM public.master_apps ma

    WHERE ma.trusted_key =

          trim(current_setting('app.CURRENT_APP_ID', true))

);

$function$