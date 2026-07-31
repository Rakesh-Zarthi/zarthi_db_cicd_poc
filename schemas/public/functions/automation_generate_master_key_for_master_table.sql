CREATE OR REPLACE FUNCTION public.automation_generate_master_key_for_master_table()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_table_name text := trim(coalesce(NEW.table_name, ''));

    v_table_api   text := trim(coalesce(NEW.table_api_name, ''));

BEGIN

    ----------------------------------------------------------------------

    -- 0. Protect immutability of table_api_name ΓÇö fail early

    ----------------------------------------------------------------------

    IF TG_OP = 'UPDATE' AND NEW.table_api_name IS DISTINCT FROM OLD.table_api_name THEN

        RAISE EXCEPTION '≡ƒÜ½ table_api_name is immutable and cannot be changed (attempted: % ΓåÆ %).',

            OLD.table_api_name, NEW.table_api_name;

    END IF;



    ----------------------------------------------------------------------

    -- 1. Validate table_name (display label)

    ----------------------------------------------------------------------

    IF v_table_name = '' THEN

        RAISE EXCEPTION 'Γ¥î table_name cannot be empty.';

    END IF;



    ----------------------------------------------------------------------

    -- 2. Validate table_api_name (must be present and conform)

    ----------------------------------------------------------------------

    IF v_table_api = '' THEN

        RAISE EXCEPTION 'Γ¥î table_api_name cannot be empty.';

    END IF;



    -- Must be a Postgres-safe identifier (lowercase start, letters/numbers/underscore)

    IF v_table_api !~ '^[a-z][a-z0-9_]*$' THEN

        RAISE EXCEPTION

            'Γ¥î Invalid table_api_name "%". Must match ^[a-z][a-z0-9_]*$ (lowercase, start with letter).',

            v_table_api;

    END IF;



    IF length(v_table_api) > 63 THEN

        RAISE EXCEPTION

            'Γ¥î table_api_name "%" exceeds PostgreSQL identifier limit (63 chars).',

            v_table_api;

    END IF;



    ----------------------------------------------------------------------

    -- 3. Compose stable in_record_name from display name + API name

    --    (business rule: in_record_name = table_name || '_' || table_api_name)

    ----------------------------------------------------------------------

    NEW.in_record_name := v_table_name || '_' || v_table_api;



    ----------------------------------------------------------------------

    -- 4. Return the row (works for INSERT and UPDATE of table_name)

    ----------------------------------------------------------------------

    RETURN NEW;

END;

$function$