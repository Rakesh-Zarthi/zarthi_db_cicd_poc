CREATE OR REPLACE FUNCTION public.master_node_gen_pipeline_execute_manual()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    rec RECORD;

BEGIN

    ------------------------------------------------------------------

    -- Iterate through dependency graph

    ------------------------------------------------------------------

    FOR rec IN

        SELECT 

            m1.table_api_name,

            n1.node_api_name

        FROM master_node_dependency d1

        JOIN master_node n1 

            ON d1.ref_master_node_in_record_id_generated = n1.in_record_id

        JOIN master_table m1 

            ON n1.ref_master_table_in_record_id = m1.in_record_id

        -- Optional: enforce deterministic order

        ORDER BY n1.node_sequence_number NULLS LAST

    LOOP



        ------------------------------------------------------------------

        -- Debug visibility

        ------------------------------------------------------------------

        RAISE NOTICE 'Executing node: %.%', rec.table_api_name, rec.node_api_name;



        ------------------------------------------------------------------

        -- Execute node

        ------------------------------------------------------------------

        PERFORM public.master_node_gen_pipeline_execute(

            rec.table_api_name,

            rec.node_api_name

        );



    END LOOP;



END;

$function$