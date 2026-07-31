CREATE OR REPLACE FUNCTION public.list_schemas(search text DEFAULT NULL::text, limit_rows integer DEFAULT 20, offset_rows integer DEFAULT 0)
 RETURNS TABLE(schema_name text)
 LANGUAGE sql
 STABLE
AS $function$

SELECT n.nspname AS schema_name

FROM pg_namespace n

WHERE n.nspname NOT LIKE 'pg_%'

  AND n.nspname <> 'information_schema'

  AND (

      search IS NULL

      OR search = ''

      OR LOWER(n.nspname) LIKE LOWER('%' || search || '%')

  )

ORDER BY n.nspname

LIMIT GREATEST(limit_rows, 1)

OFFSET GREATEST(offset_rows, 0);

$function$