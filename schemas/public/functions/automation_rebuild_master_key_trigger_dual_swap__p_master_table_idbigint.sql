CREATE OR REPLACE FUNCTION public.automation_rebuild_master_key_trigger_dual_swap(p_master_table_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_table_api text;

    v_schema    text;

    v_columns   text;

    v_lock_key  bigint;

BEGIN

    ------------------------------------------------------------------

    -- Resolve table

    ------------------------------------------------------------------

    SELECT mt.table_api_name,

           COALESCE(mt.schema, 'public')

    INTO v_table_api, v_schema

    FROM public.master_table mt

    WHERE mt.in_record_id = p_master_table_id;



    IF v_table_api IS NULL THEN

        RAISE EXCEPTION

            'Master table % not found for trigger rebuild',

            p_master_table_id;

    END IF;



    ------------------------------------------------------------------

    -- Fetch STATIC master-key columns

    ------------------------------------------------------------------

    SELECT string_agg(quote_ident(mn.node_api_name), ', ')

    INTO v_columns

    FROM public.master_node mn

    WHERE mn.ref_master_table_in_record_id = p_master_table_id

      AND COALESCE(mn.is_master_key, FALSE) = TRUE;



    IF v_columns IS NULL THEN

        RAISE EXCEPTION

            'No master-key columns defined for table %',

            v_table_api;

    END IF;



    ------------------------------------------------------------------

    -- Acquire advisory lock (per table)

    ------------------------------------------------------------------

    v_lock_key := hashtext(v_schema || '.' || v_table_api);

    PERFORM pg_advisory_xact_lock(v_lock_key);



    ------------------------------------------------------------------

    -- Atomic rebuild (no temp trigger)

    ------------------------------------------------------------------

    EXECUTE format(

        'DROP TRIGGER IF EXISTS trg_generate_master_key ON %I.%I',

        v_schema,

        v_table_api

    );



    EXECUTE format(

        'CREATE TRIGGER trg_generate_master_key

         BEFORE INSERT

             OR UPDATE OF %s

         ON %I.%I

         FOR EACH ROW

         EXECUTE FUNCTION public.automation_generate_master_key_dynamic_table_wrapper()',

        v_columns,

        v_schema,

        v_table_api

    );

END;

$function$