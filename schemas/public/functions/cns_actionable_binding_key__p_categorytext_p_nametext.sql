CREATE OR REPLACE FUNCTION public.cns_actionable_binding_key(p_category text, p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$

SELECT

    'app.actionable.bind.' ||

    trim(both '_' FROM regexp_replace(lower(coalesce(p_category,'unknown')),'[^a-z0-9]+','_','g'))

    || '.' ||

    trim(both '_' FROM regexp_replace(lower(coalesce(p_name,'unknown')),'[^a-z0-9]+','_','g'));

$function$