CREATE OR REPLACE FUNCTION public.fn_create_table()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE

	v_sql text;
	v_new_table_name text;
	v_table_to_inherit text := 'master_key';
	v_pk_column text := 'in_record_id';
	BEGIN

	RAISE NOTICE 'Entered';

	v_new_table_name := NEW.table_api_name;
	-- Create new table inheriting master_key
    v_sql := format('CREATE TABLE public.%I () INHERITS (public.%I);', v_new_table_name, v_table_to_inherit);
    EXECUTE v_sql;

	-- Add PK
	v_sql := format('ALTER TABLE public.%I ADD CONSTRAINT pk_in_record_id PRIMARY KEY (%I);', v_new_table_name, v_pk_column);
    EXECUTE v_sql;

	----------------------------------------------------------------
    -- 2∩╕ÅΓâú Standard metadata triggers (added/modified/log)
    ----------------------------------------------------------------
    -- Set "added_user" and "added_time"
    v_sql := format($sql$
        CREATE TRIGGER trg_set_added_logs
        AFTER INSERT ON public.%1$I
        FOR EACH ROW
        EXECUTE FUNCTION public.set_added_fields();
    $sql$, v_new_table_name);
    RAISE NOTICE 'SQL: %', v_sql;
	EXECUTE v_sql;

    -- Set "modified_user" and "modified_time"
    v_sql := format($sql$
        CREATE TRIGGER trg_set_modified_logs
        AFTER INSERT OR UPDATE ON public.%1$I
        FOR EACH ROW
        EXECUTE FUNCTION public.set_modified_fields();
    $sql$, v_new_table_name);
	RAISE NOTICE 'SQL: %', v_sql;
	EXECUTE v_sql;

    -- Log table changes
    v_sql := format($sql$
        CREATE TRIGGER trg_log_table_changes
        AFTER INSERT OR UPDATE OR DELETE ON public.%1$I
        FOR EACH ROW
        EXECUTE FUNCTION public.log_table_changes();
    $sql$, v_new_table_name);
    RAISE NOTICE 'SQL: %', v_sql;
	EXECUTE v_sql;

	RETURN NEW;

	END;
$function$