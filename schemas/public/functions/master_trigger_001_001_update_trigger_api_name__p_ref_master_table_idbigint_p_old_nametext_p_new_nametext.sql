CREATE OR REPLACE FUNCTION public.master_trigger_001_001_update_trigger_api_name(p_ref_master_table_id bigint, p_old_name text, p_new_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$

DECLARE

    v_schema text;

    v_table  text;

    v_exists boolean;

    v_sql    text;

    v_prev_system_write text;

BEGIN



    IF p_old_name IS NOT DISTINCT FROM p_new_name THEN

        RETURN;

    END IF;



    IF p_new_name IS NULL OR p_old_name IS NULL THEN

        RAISE EXCEPTION 'Trigger names cannot be NULL';

    END IF;



    IF p_new_name !~ '^[a-z0-9_]+$' THEN

        RAISE EXCEPTION

        'Invalid trigger_api_name "%". Must match ^[a-z0-9_]+$',

        p_new_name;

    END IF;



    ----------------------------------------------------------------

    -- FIXED: "schema"

    ----------------------------------------------------------------

    SELECT "schema", table_api_name

    INTO v_schema, v_table

    FROM public.master_table

    WHERE in_record_id = p_ref_master_table_id;



    IF v_schema IS NULL THEN

        RAISE EXCEPTION

        'master_table not found for id=%',

        p_ref_master_table_id;

    END IF;



    ----------------------------------------------------------------

    -- Validate trigger existence

    ----------------------------------------------------------------

    SELECT EXISTS (

        SELECT 1

        FROM pg_trigger t

        JOIN pg_class c ON c.oid = t.tgrelid

        JOIN pg_namespace n ON n.oid = c.relnamespace

        WHERE t.tgname = p_old_name

        AND c.relname = v_table

        AND n.nspname = v_schema

    ) INTO v_exists;



    IF NOT v_exists THEN

        RAISE EXCEPTION

        'Physical trigger "%" not found on %.%',

        p_old_name, v_schema, v_table;

    END IF;



    ----------------------------------------------------------------

    -- Check new name conflict

    ----------------------------------------------------------------

    SELECT EXISTS (

        SELECT 1

        FROM pg_trigger t

        JOIN pg_class c ON c.oid = t.tgrelid

        JOIN pg_namespace n ON n.oid = c.relnamespace

        WHERE t.tgname = p_new_name

        AND c.relname = v_table

        AND n.nspname = v_schema

    ) INTO v_exists;



    IF v_exists THEN

        RAISE EXCEPTION

        'Trigger "%" already exists on %.%',

        p_new_name, v_schema, v_table;

    END IF;



    ----------------------------------------------------------------

    -- Safe execution

    ----------------------------------------------------------------

    v_prev_system_write := current_setting('app.system_write', true);



    BEGIN

        PERFORM set_config('app.system_write','true',true);



        v_sql := format(

            'ALTER TRIGGER %I ON %I.%I RENAME TO %I',

            p_old_name,

            v_schema,

            v_table,

            p_new_name

        );



        EXECUTE v_sql;



    EXCEPTION WHEN OTHERS THEN

        PERFORM set_config('app.system_write', COALESCE(v_prev_system_write,'false'), true);

        RAISE;

    END;



    PERFORM set_config('app.system_write', COALESCE(v_prev_system_write,'false'), true);



END;

$function$