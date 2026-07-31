CREATE OR REPLACE FUNCTION public.fn_collect_inserted_nodes()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_table_name  text;

    v_column_name text;

    v_data_type   text;

    v_sql         text;

BEGIN

    --  Prevent recursive trigger loop

    IF current_setting('app.recursion_guard', true) IS NOT NULL THEN

        RETURN NEW;

    END IF;

    PERFORM set_config('app.recursion_guard', 'true', true);



    --  your main logic here (unchanged)

    -- ...

    -- ALTER TABLE etc.



    --  Reset recursion flag

    PERFORM set_config('app.recursion_guard', NULL, true);

    RETURN NEW;

END;

$function$