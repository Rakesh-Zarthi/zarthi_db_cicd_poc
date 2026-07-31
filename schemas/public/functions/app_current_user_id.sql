CREATE OR REPLACE FUNCTION public.app_current_user_id()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
    SELECT current_setting('app.CURRENT_USER_ID', true);
$function$