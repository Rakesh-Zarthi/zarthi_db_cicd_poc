CREATE OR REPLACE FUNCTION public.app_current_user_uuid_policy_helper()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$

SELECT current_setting('app.CURRENT_USER_ID', true)::uuid;

$function$