CREATE OR REPLACE FUNCTION public.master_table_rebuild_self_access_control_trigger(p_master_table_id bigint, p_enable boolean)
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



    v_self_columns  text;

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

v_lock_key := hashtext(v_schema || '.' || v_table || '.self_acl');

PERFORM pg_advisory_xact_lock(v_lock_key);



------------------------------------------------------------------

-- Resolve SELF trigger columns from metadata

------------------------------------------------------------------

SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY a.attnum)

INTO v_self_columns

FROM pg_attribute a

JOIN public.master_node mn

  ON mn.node_api_name = a.attname

WHERE a.attrelid = v_table_oid

AND a.attnum > 0

AND NOT a.attisdropped

AND mn.ref_master_table_in_record_id = p_master_table_id

AND (

        mn.node_api_name IN

        (

            'in_record_id',

            'in_ref_master_table'

        )

     OR (

            mn.node_data_type IN

            (

                'One-One Lookup',

                'One-Many Lookup'

            )

            AND mn.ref_master_table_in_record_id_connected IS NOT NULL

        )

    )

AND mn.node_api_name NOT LIKE 'inv_%';



------------------------------------------------------------------

-- Drop trigger (atomic rebuild)

------------------------------------------------------------------

EXECUTE format(

' DROP TRIGGER IF EXISTS tgr_1_5_self_update_master_access_control

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

IF v_self_columns IS NOT NULL THEN



EXECUTE format(

'CREATE TRIGGER tgr_1_5_self_update_master_access_control

 BEFORE INSERT

    OR UPDATE OF %s

 ON %I.%I

 FOR EACH ROW

 EXECUTE FUNCTION public.global_tgr_self_update_acl_column_scoped()',

v_self_columns,

v_schema,

v_table

);



END IF;



END;

$function$