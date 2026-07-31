CREATE OR REPLACE FUNCTION public.automation_attach_global_triggers(_table_name text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_table text := lower(trim(_table_name));

    v_sql text;

BEGIN

    ----------------------------------------------------------------

    -- 1∩╕Å Validate table exists

    ----------------------------------------------------------------

    IF v_table IS NULL OR v_table = '' THEN

        RAISE EXCEPTION 'Γ¥î automation_attach_global_triggers: table name cannot be empty.';

    END IF;



    IF NOT EXISTS (

        SELECT 1 FROM pg_class

        WHERE relname = v_table

        AND relnamespace = 'public'::regnamespace

    ) THEN

        RAISE EXCEPTION 'Γ¥î automation_attach_global_triggers: table "%" does not exist.', v_table;

    END IF;





    ----------------------------------------------------------------

    -- 2∩╕Å tgr001_no_delete ΓÇö prevent delete

    ----------------------------------------------------------------

    v_sql := format($sql$

        CREATE TRIGGER tgr_2_1_prevent_user_write

        BEFORE DELETE ON public.%1$I

        FOR EACH ROW EXECUTE FUNCTION public.global_prevent_user_write();

    $sql$, v_table);

    EXECUTE v_sql;

/*

    ----------------------------------------------------------------

    -- 5 tgr004_set_table_api ΓÇö Master key generation trigger

    ----------------------------------------------------------------

     v_sql := format($sql$

        CREATE TRIGGER tgr_2_2_generate_master_key

        BEFORE INSERT ON public.%1$I

        FOR EACH ROW

        EXECUTE FUNCTION public.automation_generate_master_key_dynamic_table_wrapper('%1$I');

    $sql$, v_table);

    EXECUTE v_sql; */



    ----------------------------------------------------------------

    -- 3∩╕Å tgr002_set_added_fields ΓÇö added metadata

    ----------------------------------------------------------------

    v_sql := format($sql$

        CREATE TRIGGER tgr_2_3_set_added_fields

        BEFORE INSERT ON public.%1$I

        FOR EACH ROW EXECUTE FUNCTION public.global_set_added_fields();

    $sql$, v_table);

    EXECUTE v_sql;





    ----------------------------------------------------------------

    -- 4∩╕Å tgr003_set_modified_fields ΓÇö modified metadata

    ----------------------------------------------------------------

    v_sql := format($sql$

        CREATE TRIGGER tgr_2_4_set_modified_fields

        BEFORE UPDATE ON public.%1$I

        FOR EACH ROW EXECUTE FUNCTION public.global_set_modified_fields();

    $sql$, v_table);

    EXECUTE v_sql;



    ----------------------------------------------------------------

    -- 7∩╕ÅΓâú Success

    ----------------------------------------------------------------

    RAISE NOTICE 'Γ£à Attached global triggers for table "%".', v_table;



EXCEPTION WHEN OTHERS THEN

    RAISE EXCEPTION '≡ƒÆÑ Failed attaching global triggers for table "%": %',

        v_table, SQLERRM;



END;

$function$