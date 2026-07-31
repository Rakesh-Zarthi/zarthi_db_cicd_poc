CREATE OR REPLACE FUNCTION public.master_tables_001_wrapper_import_single_metadata(p_table_api_name text, p_update_existing boolean DEFAULT true, p_lock boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$



DECLARE

    v_user text := current_user;

    v_started_at timestamptz := clock_timestamp();



    v_schema_name text;

    v_table_name text;



    v_result jsonb;



BEGIN



    ------------------------------------------------------------

    -- Permission Check

    ------------------------------------------------------------

    IF v_user NOT IN ('postgres','admin2','admin','superuser') THEN

        RAISE EXCEPTION

            'Permission denied for user "%". Only admin/superuser allowed.',

            v_user

            USING ERRCODE='42501';

    END IF;



    ------------------------------------------------------------

    -- Locate table

    ------------------------------------------------------------

    SELECT

        n.nspname,

        c.relname

    INTO

        v_schema_name,

        v_table_name

    FROM pg_class c

    JOIN pg_namespace n

        ON n.oid = c.relnamespace

    WHERE c.relkind IN ('r','p')

      AND c.relname = p_table_api_name

      AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')

      AND n.nspname NOT LIKE 'pg_%'

    LIMIT 1;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Table "%" does not exist.',

            p_table_api_name;

    END IF;



    ------------------------------------------------------------

    -- Import Metadata

    ------------------------------------------------------------

    v_result :=

        public.master_tables_001_import_metadata(

            v_schema_name,

            v_table_name,

            p_update_existing,

            p_lock

        );



    RETURN jsonb_build_object(

        'status', 'complete',

        'schema_name', v_schema_name,

        'table_name', v_table_name,

        'duration_seconds',

            ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_started_at), 2),

        'result', v_result

    );



END;

$function$