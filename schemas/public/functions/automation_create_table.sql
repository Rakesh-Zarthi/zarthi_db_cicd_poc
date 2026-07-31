CREATE OR REPLACE FUNCTION public.automation_create_table()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

DECLARE

    v_user           text := current_user;

    v_schema_name    text;

    v_table_api_raw  text;

    v_table_sql_name text;

    v_oid            oid;

    v_skip_creation  boolean := false;

BEGIN



    ------------------------------------------------------------------

    -- Only INSERT

    ------------------------------------------------------------------

    IF TG_OP <> 'INSERT' THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Skip mode

    ------------------------------------------------------------------

    v_skip_creation :=

        current_setting('app.skip_dynamic_table_creation', true) = 'true';



    IF v_skip_creation THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Permission check

    ------------------------------------------------------------------

    IF v_user NOT IN ('postgres','admin','superuser') THEN

        RAISE EXCEPTION

        'Permission denied for dynamic table creation';

    END IF;



    ------------------------------------------------------------------

    -- Resolve schema

    ------------------------------------------------------------------

    v_schema_name :=

        COALESCE(NULLIF(trim(NEW.schema), ''), 'public');



    ------------------------------------------------------------------

    -- Resolve table name

    ------------------------------------------------------------------

    v_table_api_raw := trim(NEW.table_api_name);



    IF v_table_api_raw IS NULL OR v_table_api_raw = '' THEN

        RAISE EXCEPTION 'table_api_name cannot be empty';

    END IF;



    v_table_sql_name := lower(v_table_api_raw);



    IF v_table_sql_name !~ '^[a-z][a-z0-9_]*$' THEN

        RAISE EXCEPTION

        'Invalid table_api_name: %', v_table_api_raw;

    END IF;



    IF length(v_table_sql_name) > 63 THEN

        RAISE EXCEPTION

        'table_api_name too long: %', v_table_api_raw;

    END IF;



    ------------------------------------------------------------------

    -- Check if exists

    ------------------------------------------------------------------

    SELECT c.oid

    INTO v_oid

    FROM pg_class c

    JOIN pg_namespace n ON n.oid = c.relnamespace

    WHERE n.nspname = v_schema_name

    AND c.relname = v_table_sql_name;



    IF v_oid IS NOT NULL THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Create table safely

    ------------------------------------------------------------------

    BEGIN



        PERFORM pg_advisory_xact_lock(

            hashtext(v_schema_name||'.'||v_table_sql_name)

        );



        ------------------------------------------------------------------

        -- CREATE TABLE

        ------------------------------------------------------------------

        EXECUTE format(

            'CREATE TABLE %I.%I () INHERITS (public.master_key)',

            v_schema_name,

            v_table_sql_name

        );



        ------------------------------------------------------------------

        -- Add identity safely

        ------------------------------------------------------------------

IF NOT EXISTS (

    SELECT 1

    FROM pg_class c

    JOIN pg_namespace n ON n.oid = c.relnamespace

    JOIN pg_attribute a ON a.attrelid = c.oid

    WHERE n.nspname = v_schema_name

    AND c.relname = v_table_sql_name

    AND a.attname = 'in_record_id'

    AND a.attidentity <> ''

)

THEN



    EXECUTE format(

        'ALTER TABLE %I.%I

         ALTER COLUMN in_record_id

         ADD GENERATED ALWAYS AS IDENTITY',

        v_schema_name,

        v_table_sql_name

    );



END IF;



        ------------------------------------------------------------------

        -- Primary key

        ------------------------------------------------------------------

        EXECUTE format(

            'ALTER TABLE %I.%I

             ADD CONSTRAINT pk_%I

             PRIMARY KEY (in_record_id)',

            v_schema_name,

            v_table_sql_name,

            v_table_sql_name

        );



        ------------------------------------------------------------------

        -- Attach triggers

        ------------------------------------------------------------------

        PERFORM public.automation_attach_global_triggers(

            v_table_sql_name

        );



        ------------------------------------------------------------------

        -- Handle RLS

        ------------------------------------------------------------------

        IF NEW.rls_enabled IS TRUE THEN



            EXECUTE format(

                'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',

                v_schema_name,

                v_table_sql_name

            );



            PERFORM public.ac_create_row_level_security_policies(

                v_schema_name,

                v_table_sql_name,

                true

            );



        ELSE



            EXECUTE format(

                'ALTER TABLE %I.%I DISABLE ROW LEVEL SECURITY',

                v_schema_name,

                v_table_sql_name

            );



        END IF;



    EXCEPTION

        WHEN OTHERS THEN



            IF EXISTS (

                SELECT 1

                FROM pg_class c

                JOIN pg_namespace n

                ON n.oid = c.relnamespace

                WHERE n.nspname = v_schema_name

                AND c.relname = v_table_sql_name

            )

            THEN

                EXECUTE format(

                    'DROP TABLE %I.%I CASCADE',

                    v_schema_name,

                    v_table_sql_name

                );

            END IF;



            RAISE EXCEPTION

            'Dynamic table creation failed: %.% : %',

            v_schema_name,

            v_table_sql_name,

            SQLERRM;



    END;



    RETURN NEW;



END;

$function$