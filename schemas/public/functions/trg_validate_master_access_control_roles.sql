CREATE OR REPLACE FUNCTION public.trg_validate_master_access_control_roles()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_permission public.dropdown;

    v_perm_dedup text[];

BEGIN

    ------------------------------------------------------------------

    -- 0) Permission array sanity

    ------------------------------------------------------------------

    IF NEW.permission IS NULL OR array_length(NEW.permission, 1) IS NULL THEN

        RAISE EXCEPTION 'permission cannot be empty';

    END IF;



    ------------------------------------------------------------------

    -- 1) Deduplicate permissions

    ------------------------------------------------------------------

    SELECT ARRAY(

        SELECT DISTINCT p::text

        FROM unnest(NEW.permission) AS p

        ORDER BY 1

    )

    INTO v_perm_dedup;



    NEW.permission := v_perm_dedup::public._dropdown;



    ------------------------------------------------------------------

    -- 2) STRICT ENFORCEMENT:

    --    Non-root rows cannot exist unless root already exists.

    ------------------------------------------------------------------

    IF NEW.is_root IS NOT TRUE THEN

        IF NOT EXISTS (

            SELECT 1

            FROM public.master_table_access_control_users_roles mac

            WHERE mac.ref_users_roles_in_record_id = NEW.ref_users_roles_in_record_id

              AND mac.is_root = true

              AND mac.in_record_id <> COALESCE(NEW.in_record_id, -1)

        ) THEN

            RAISE EXCEPTION

                'Access config invalid: users_role % has no root configured. Create root entry first.',

                NEW.ref_users_roles_in_record_id;

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- 3) Root must contain Select permission

    ------------------------------------------------------------------

    IF NEW.is_root IS TRUE

       AND NOT ('Select'::public.dropdown = ANY(NEW.permission)) THEN

        RAISE EXCEPTION

            'Root config invalid: Select permission is mandatory for root table (users_role %)',

            NEW.ref_users_roles_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- 4) Validate constraints for each permission

    ------------------------------------------------------------------

    FOREACH v_permission IN ARRAY NEW.permission

    LOOP

        PERFORM public.validate_master_access_chain_roles(

            NEW.ref_users_roles_in_record_id,

            v_permission,

            COALESCE(NEW.in_record_id, -1),

            NEW.is_root,

            NEW.ref_master_table_in_record_id_to

        );

    END LOOP;



    RETURN NEW;

END;

$function$