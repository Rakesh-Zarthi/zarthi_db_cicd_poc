CREATE OR REPLACE FUNCTION public.validate_master_access_chain_roles(p_users_role bigint, p_required_permission dropdown, p_exclude_record_id bigint, p_is_root boolean, p_to_table bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_existing_root_count int;

    v_total_root_count    int;

BEGIN

    ------------------------------------------------------------------

    -- 0) Basic sanity

    ------------------------------------------------------------------

    IF p_users_role IS NULL THEN

        RAISE EXCEPTION 'users_role cannot be NULL';

    END IF;



    IF p_to_table IS NULL THEN

        RAISE EXCEPTION

            'Access config invalid: ref_master_table_in_record_id_to cannot be NULL (users_role %)',

            p_users_role;

    END IF;



    ------------------------------------------------------------------

    -- 1) Count existing roots excluding current row

    ------------------------------------------------------------------

    SELECT COUNT(*)

    INTO v_existing_root_count

    FROM public.master_table_access_control_users_roles mac

    WHERE mac.ref_users_roles_in_record_id = p_users_role

      AND mac.in_record_id <> p_exclude_record_id

      AND mac.is_root = true;



    ------------------------------------------------------------------

    -- 2) Exactly one root AFTER change

    ------------------------------------------------------------------

    v_total_root_count :=

        v_existing_root_count

        + CASE WHEN p_is_root IS TRUE THEN 1 ELSE 0 END;



    IF v_total_root_count <> 1 THEN

        RAISE EXCEPTION

            'Access config invalid: users_role % must have exactly one root (found %)',

            p_users_role,

            v_total_root_count;

    END IF;



    ------------------------------------------------------------------

    -- Root Select rule handled in trigger.

    ------------------------------------------------------------------

END;

$function$