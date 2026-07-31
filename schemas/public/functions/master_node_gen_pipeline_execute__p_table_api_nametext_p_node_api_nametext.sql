CREATE OR REPLACE FUNCTION public.master_node_gen_pipeline_execute(p_table_api_name text, p_node_api_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

DECLARE

    v_node_execution_code text;

    v_target_column text;

    v_sql text;

BEGIN

    ------------------------------------------------------------------

    -- Guard

    ------------------------------------------------------------------

    IF p_table_api_name IS NULL OR p_node_api_name IS NULL THEN

        RAISE NOTICE 'Invalid input';

        RETURN;

    END IF;



    ------------------------------------------------------------------

    -- Fetch node metadata

    ------------------------------------------------------------------

    SELECT 

        n.node_execution_code,

        n.node_api_name   

    INTO 

        v_node_execution_code,

        v_target_column

    FROM public.master_node n

    JOIN public.master_table mt

        ON mt.in_record_id = n.ref_master_table_in_record_id

    WHERE n.node_api_name = p_node_api_name

      AND mt.table_api_name = p_table_api_name

    LIMIT 1;



    ------------------------------------------------------------------

    -- Validate

    ------------------------------------------------------------------

    IF v_node_execution_code IS NULL THEN

        RAISE NOTICE 'No execution code for node=%', p_node_api_name;

        RETURN;

    END IF;



    IF v_target_column IS NULL THEN

        RAISE NOTICE 'No target column defined for node=%', p_node_api_name;

        RETURN;

    END IF;



    ------------------------------------------------------------------

    -- Build drift-safe UPDATE

    ------------------------------------------------------------------

    v_sql := format($fmt$

        WITH computed AS (

            %s

        )

        UPDATE %I t

        SET %I = c.node_value

        FROM computed c

        WHERE t.in_record_id = c.in_record_id

          AND t.%I IS DISTINCT FROM c.node_value

    $fmt$,

        v_node_execution_code,

        p_table_api_name,

        v_target_column,

        v_target_column

    );



    ------------------------------------------------------------------

    -- Debug (IMPORTANT)

    ------------------------------------------------------------------

    RAISE NOTICE 'Executing SQL: %', v_sql;



    ------------------------------------------------------------------

    -- Execute

    ------------------------------------------------------------------

    EXECUTE v_sql;



END;

$function$