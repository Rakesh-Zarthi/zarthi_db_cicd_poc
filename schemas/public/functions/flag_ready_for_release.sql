CREATE OR REPLACE FUNCTION public.flag_ready_for_release()
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_count INT := 0;

BEGIN

    -- Tables, Views, MatViews, Sequences

    SELECT COUNT(*) INTO v_count

    FROM pg_class c

    JOIN pg_namespace n ON n.oid = c.relnamespace

    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')

      AND c.relkind IN ('r','v','m','S')

      AND pg_get_userbyid(c.relowner) NOT IN  ('admin','rdsadmin','postgres', 'rds_superuser');



    IF v_count > 0 THEN

        RETURN FALSE;

    END IF;



    -- Functions & Procedures

    SELECT COUNT(*) INTO v_count

    FROM pg_proc p

    JOIN pg_namespace n ON n.oid = p.pronamespace

    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')

      AND p.prokind IN ('f','p')

      AND pg_get_userbyid(p.proowner) NOT IN  ('admin','rdsadmin','postgres','rds_superuser');





    IF v_count > 0 THEN

        RETURN FALSE;

    END IF;



    RETURN TRUE;

END;

$function$