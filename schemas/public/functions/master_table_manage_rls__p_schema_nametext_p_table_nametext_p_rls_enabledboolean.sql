CREATE OR REPLACE FUNCTION public.master_table_manage_rls(p_schema_name text, p_table_name text, p_rls_enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

DECLARE

    v_exists boolean;

BEGIN



    ------------------------------------------------------------------

    -- Validate table exists

    ------------------------------------------------------------------

    SELECT EXISTS (

        SELECT 1

        FROM pg_class c

        JOIN pg_namespace n ON n.oid = c.relnamespace

        WHERE n.nspname = p_schema_name

        AND c.relname = p_table_name

    )

    INTO v_exists;



    IF NOT v_exists THEN

        RAISE EXCEPTION

        'Table %.% does not exist',

        p_schema_name,

        p_table_name;

    END IF;



    ------------------------------------------------------------------

    -- ENABLE RLS

    ------------------------------------------------------------------

    IF p_rls_enabled THEN



        EXECUTE format(

            'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',

            p_schema_name,

            p_table_name

        );



        ------------------------------------------------------------------

        -- Create policies

        ------------------------------------------------------------------

        PERFORM public.ac_create_row_level_security_policies(

            p_schema_name,

            p_table_name,

            true

        );



        RAISE NOTICE

        'RLS enabled and policies created on %.%',

        p_schema_name,

        p_table_name;



    ------------------------------------------------------------------

    -- DISABLE RLS

    ------------------------------------------------------------------

    ELSE



        ------------------------------------------------------------------

        -- Drop policies first

        ------------------------------------------------------------------

        EXECUTE format(

            'DROP POLICY IF EXISTS rls_%1$I_select ON %2$I.%1$I',

            p_table_name,

            p_schema_name

        );



        EXECUTE format(

            'DROP POLICY IF EXISTS rls_%1$I_insert ON %2$I.%1$I',

            p_table_name,

            p_schema_name

        );



        EXECUTE format(

            'DROP POLICY IF EXISTS rls_%1$I_update ON %2$I.%1$I',

            p_table_name,

            p_schema_name

        );



        EXECUTE format(

            'DROP POLICY IF EXISTS rls_%1$I_delete ON %2$I.%1$I',

            p_table_name,

            p_schema_name

        );



        ------------------------------------------------------------------

        -- Disable RLS

        ------------------------------------------------------------------

        EXECUTE format(

            'ALTER TABLE %I.%I DISABLE ROW LEVEL SECURITY',

            p_schema_name,

            p_table_name

        );



        RAISE NOTICE

        'RLS disabled and policies dropped on %.%',

        p_schema_name,

        p_table_name;



    END IF;



END;

$function$