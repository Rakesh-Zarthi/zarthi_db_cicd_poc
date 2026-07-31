CREATE OR REPLACE FUNCTION public.app_scope_policy_helper(p_table text, p_action text)
 RETURNS smallint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$

SELECT

CASE lower(p_action)

WHEN 'select' THEN COALESCE(p.select_permission, a.default_select_permission)

WHEN 'insert' THEN COALESCE(p.insert_permission, a.default_insert_permission)

WHEN 'update' THEN COALESCE(p.update_permission, a.default_update_permission)

WHEN 'delete' THEN COALESCE(p.delete_permission, a.default_delete_permission)

ELSE 0

END

FROM master_apps a

JOIN master_table t

    ON t.table_api_name = p_table

LEFT JOIN master_apps_table_permissions p

    ON p.ref_master_apps_in_record_id = a.in_record_id

   AND p.ref_master_table_in_record_id = t.in_record_id

WHERE a.trusted_key =

      trim(current_setting('app.CURRENT_APP_ID', true))

LIMIT 1;

$function$