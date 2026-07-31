CREATE OR REPLACE FUNCTION public.automation_validate_master_node()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_bypass BOOLEAN := FALSE;

BEGIN

    ----------------------------------------------------------------------

    -- ≡ƒö╣ 0∩╕ÅΓâú Read bypass flag (safe even if not set)

    ----------------------------------------------------------------------

    BEGIN

        v_bypass := current_setting('app.bypass_validation', true)::BOOLEAN;

    EXCEPTION

        WHEN others THEN

            v_bypass := FALSE;

    END;



    ----------------------------------------------------------------------

    -- ≡ƒö╣ ≡ƒÜÇ If bypass enabled ΓåÆ skip all validations

    ----------------------------------------------------------------------

    IF v_bypass THEN

        RETURN NEW;

    END IF;



    ----------------------------------------------------------------------

    -- 1∩╕ÅΓâú Enforce rule:

    --    If is_master_key = TRUE ΓåÆ is_mandatory must also be TRUE

    ----------------------------------------------------------------------

    IF NEW.is_master_key = TRUE

       AND NEW.is_mandatory IS DISTINCT FROM TRUE THEN

        RAISE EXCEPTION

            'Γ¥î Validation failed: is_mandatory must be TRUE when is_master_key is TRUE (node_label=%)',

            NEW.node_label;

    END IF;



    ----------------------------------------------------------------------

    -- 2∩╕ÅΓâú Prevent node_api_name modifications (immutable)

    ----------------------------------------------------------------------

    IF TG_OP = 'UPDATE'

       AND NEW.node_api_name IS DISTINCT FROM OLD.node_api_name THEN

        RAISE EXCEPTION

            'Γ¥î node_api_name is immutable. Existing: %, attempted: %',

            OLD.node_api_name, NEW.node_api_name;

    END IF;



    ----------------------------------------------------------------------

    -- 3∩╕ÅΓâú Prevent node_data_type modifications (immutable)

    ----------------------------------------------------------------------

    IF TG_OP = 'UPDATE'

       AND NEW.node_data_type IS DISTINCT FROM OLD.node_data_type THEN

        RAISE EXCEPTION

            'Γ¥î node_data_type is immutable. Existing: %, attempted: %',

            OLD.node_data_type, NEW.node_data_type;

    END IF;



    RETURN NEW;

END;

$function$