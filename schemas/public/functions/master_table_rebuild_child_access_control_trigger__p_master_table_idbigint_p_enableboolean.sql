CREATE OR REPLACE FUNCTION public.master_table_rebuild_child_access_control_trigger(p_master_table_id bigint, p_enable boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

DECLARE

    v_schema        text;

    v_table         text;

    v_table_reg     regclass;

    v_table_oid     oid;



    v_child_columns text;

    v_lock_key      bigint;

BEGIN



------------------------------------------------------------------

-- Skip system writes

------------------------------------------------------------------

IF current_setting('app.system_write', true) = 'true' THEN

    RETURN;

END IF;



------------------------------------------------------------------

-- Resolve table metadata

------------------------------------------------------------------

SELECT mt.table_api_name,

       COALESCE(mt.schema,'public')

INTO v_table, v_schema

FROM public.master_table mt

WHERE mt.in_record_id = p_master_table_id;



IF v_table IS NULL THEN

    RAISE EXCEPTION

        'Master table % not found',

        p_master_table_id;

END IF;



------------------------------------------------------------------

-- Resolve relation

------------------------------------------------------------------

SELECT to_regclass(format('%I.%I',v_schema,v_table))

INTO v_table_reg;



IF v_table_reg IS NULL THEN

    RAISE EXCEPTION

        'Table %.% does not exist',

        v_schema,

        v_table;

END IF;



v_table_oid := v_table_reg::oid;



------------------------------------------------------------------

-- Advisory lock

------------------------------------------------------------------

v_lock_key := hashtext(v_schema || '.' || v_table || '.child_acl');

PERFORM pg_advisory_xact_lock(v_lock_key);



------------------------------------------------------------------

-- Resolve CHILD ACL columns

------------------------------------------------------------------

SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY a.attnum)

INTO v_child_columns

FROM pg_attribute a

WHERE a.attrelid = v_table_oid

AND a.attnum > 0

AND NOT a.attisdropped

AND a.attname IN

(

    'in_ref_master_request_id',

    'in_ref_master_users_id',

    'in_ref_master_users_role_id'

);



------------------------------------------------------------------

-- Drop trigger

------------------------------------------------------------------

EXECUTE format(

' DROP TRIGGER IF EXISTS tgr_9_1_child_master_access_control

  ON %I.%I',

v_schema,

v_table

);



------------------------------------------------------------------

-- Exit if disabled

------------------------------------------------------------------

IF NOT p_enable THEN

    RETURN;

END IF;



------------------------------------------------------------------

-- Create trigger

------------------------------------------------------------------

IF v_child_columns IS NOT NULL THEN



EXECUTE format(

'CREATE TRIGGER tgr_9_1_child_master_access_control

 AFTER INSERT

    OR DELETE

    OR UPDATE OF %s

 ON %I.%I

 FOR EACH ROW

 EXECUTE FUNCTION public.global_tgr_child_master_table_access_control()',

v_child_columns,

v_schema,

v_table

);



END IF;



END;

$function$