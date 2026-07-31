CREATE OR REPLACE FUNCTION public.app_usage_actionable_name(u usage)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$

  SELECT actionable_name FROM public.actionables WHERE in_record_id = u.ref_actionables_in_record_immediate_consumer LIMIT 1;

$function$