CREATE OR REPLACE FUNCTION public.app_insert_uuid_policy_helper(p_table text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$

SELECT EXISTS (

    SELECT 1

    FROM master_table t

    WHERE t.table_api_name = p_table

    AND current_setting('app.CURRENT_USER_ID', true) IS NOT NULL

    AND (

        COALESCE(

            (COALESCE(t.insert_master_users_uuid_permissions,'{}'::jsonb)->'Insert'),

            '[]'::jsonb

        )

        ? current_setting('app.CURRENT_USER_ID', true)

    )

);

$function$