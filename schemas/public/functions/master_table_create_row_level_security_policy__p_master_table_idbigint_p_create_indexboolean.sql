CREATE OR REPLACE FUNCTION public.master_table_create_row_level_security_policy(p_master_table_id bigint, p_create_index boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_schema text;

    v_table text;

BEGIN



SELECT schema, table_api_name

INTO v_schema, v_table

FROM master_table

WHERE in_record_id=p_master_table_id;



EXECUTE format(

'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',

v_schema,

v_table

);



PERFORM public.master_table_create_rls_select_policy(p_master_table_id);

PERFORM public.master_table_create_rls_insert_policy(p_master_table_id);

PERFORM public.master_table_create_rls_update_policy(p_master_table_id);

PERFORM public.master_table_create_rls_delete_policy(p_master_table_id);



IF p_create_index THEN



EXECUTE format(

'CREATE INDEX IF NOT EXISTS %I

ON %I.%I

USING GIN (in_ref_master_user_uuid jsonb_path_ops)',

format('%s_%s_acl_gin_idx',v_schema,v_table),

v_schema,

v_table

);



END IF;



END;

$function$