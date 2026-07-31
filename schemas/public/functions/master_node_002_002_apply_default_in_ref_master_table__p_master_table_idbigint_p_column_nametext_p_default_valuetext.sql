CREATE OR REPLACE FUNCTION public.master_node_002_002_apply_default_in_ref_master_table(p_master_table_id bigint, p_column_name text, p_default_value text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_table_name TEXT;

    v_sql        TEXT;

    v_exists     BOOLEAN;

BEGIN

    ------------------------------------------------------------------

    -- 1. Resolve physical table

    ------------------------------------------------------------------

    SELECT table_api_name

    INTO v_table_name

    FROM public.master_table

    WHERE in_record_id = p_master_table_id

    and table_api_name NOT IN ('master_key','requests_to_data');



    IF v_table_name IS NULL THEN

        RAISE EXCEPTION 'Γ¥î Table not found for id %', p_master_table_id;

    END IF;



    ------------------------------------------------------------------

    -- 2. Check column exists (INCLUDING inherited)

    ------------------------------------------------------------------

    SELECT EXISTS (

        SELECT 1

        FROM pg_attribute a

        JOIN pg_class c ON c.oid = a.attrelid

        JOIN pg_namespace n ON n.oid = c.relnamespace

        WHERE n.nspname = 'public'

          AND c.relname = v_table_name

          AND a.attname = p_column_name

          AND a.attnum > 0

          AND NOT a.attisdropped

    )

    INTO v_exists;



    IF NOT v_exists THEN

        RAISE EXCEPTION 'Γ¥î Column % not found in %', p_column_name, v_table_name;

    END IF;



    ------------------------------------------------------------------

    -- 3. Fix existing data (NOT NULL safe)

    ------------------------------------------------------------------

    v_sql := format(

        'UPDATE public.%I

         SET %I = %s

         WHERE %I IS DISTINCT FROM %s',

        v_table_name,

        p_column_name,

        p_default_value,

        p_column_name,

        p_default_value

    );



    RAISE NOTICE 'Backfill SQL: %', v_sql;

    EXECUTE v_sql;



    ------------------------------------------------------------------

    -- 4. Set DEFAULT for future inserts

    ------------------------------------------------------------------

    v_sql := format(

        'ALTER TABLE public.%I

         ALTER COLUMN %I SET DEFAULT %s',

        v_table_name,

        p_column_name,

        p_default_value

    );



    RAISE NOTICE 'Default SQL: %', v_sql;

    EXECUTE v_sql;



    ------------------------------------------------------------------

    -- 5. Done

    ------------------------------------------------------------------

    RAISE NOTICE 'Γ£à Backfill + default applied on %.%',

        v_table_name, p_column_name;



END;

$function$