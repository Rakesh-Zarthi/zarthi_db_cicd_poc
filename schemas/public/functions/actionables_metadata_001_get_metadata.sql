CREATE OR REPLACE FUNCTION public.actionables_metadata_001_get_metadata()
 RETURNS jsonb
 LANGUAGE sql
AS $function$

SELECT actionable_config

FROM public.actionables_execution_metadata

ORDER BY in_record_id DESC

LIMIT 1

$function$