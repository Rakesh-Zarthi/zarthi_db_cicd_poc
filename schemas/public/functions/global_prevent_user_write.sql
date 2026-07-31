CREATE OR REPLACE FUNCTION public.global_prevent_user_write()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_system_write boolean := false;

BEGIN

    ------------------------------------------------------------------

    -- SYSTEM BYPASS

    -- Used by SECURITY DEFINER functions / internal automations

    -- Example enabling call:

    --   PERFORM set_config('app.system_write','true', true);

    ------------------------------------------------------------------

    v_system_write :=

        COALESCE(current_setting('app.system_write', true), 'false') = 'true';



    IF v_system_write THEN

        RETURN COALESCE(NEW, OLD);

    END IF;



    ------------------------------------------------------------------

    -- OPTIONAL: ROLE BASED BYPASS (uncomment if needed)

    ------------------------------------------------------------------

    -- IF current_user IN ('postgres', 'app_internal') THEN

    --     RETURN COALESCE(NEW, OLD);

    -- END IF;



    ------------------------------------------------------------------

    -- DEFAULT: Block ALL direct DML

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN

        RAISE EXCEPTION 'Γ¥î Direct INSERTs into table "%" are not allowed.', TG_TABLE_NAME;

    ELSIF TG_OP = 'UPDATE' THEN

        RAISE EXCEPTION 'Γ¥î Direct UPDATEs on table "%" are not allowed.', TG_TABLE_NAME;

    ELSIF TG_OP = 'DELETE' THEN

        RAISE EXCEPTION 'Γ¥î Direct DELETEs from table "%" are not allowed.', TG_TABLE_NAME;

    END IF;



    RETURN COALESCE(NEW, OLD);

END;

$function$