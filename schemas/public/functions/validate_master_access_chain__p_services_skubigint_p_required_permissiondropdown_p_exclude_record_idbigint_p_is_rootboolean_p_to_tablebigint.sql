CREATE OR REPLACE FUNCTION public.validate_master_access_chain(p_services_sku bigint, p_required_permission dropdown, p_exclude_record_id bigint, p_is_root boolean, p_to_table bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_existing_root_count int;

    v_total_root_count    int;



    v_root_table_id       bigint;

    v_has_path            boolean;

BEGIN

    ------------------------------------------------------------------

    -- 0) Basic sanity

    ------------------------------------------------------------------

    IF p_services_sku IS NULL THEN

        RAISE EXCEPTION 'services_sku cannot be NULL';

    END IF;



    IF p_to_table IS NULL THEN

        RAISE EXCEPTION

            'Access config invalid: ref_master_table_in_record_id_to cannot be NULL (services_sku %)',

            p_services_sku;

    END IF;



    ------------------------------------------------------------------

    -- 1) Count existing roots excluding current row

    ------------------------------------------------------------------

    SELECT COUNT(*)

    INTO v_existing_root_count

    FROM public.master_table_access_control_services_sku mac

    WHERE mac.ref_services_sku_in_record_id = p_services_sku

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

            'Access config invalid: services_sku % must have exactly one root (found %)',

            p_services_sku,

            v_total_root_count;

    END IF;



    ------------------------------------------------------------------

    -- 3) Resolve root table id

    ------------------------------------------------------------------

    IF p_is_root IS TRUE THEN

        v_root_table_id := p_to_table;

    ELSE

        SELECT mac.ref_master_table_in_record_id_to

        INTO v_root_table_id

        FROM public.master_table_access_control_services_sku mac

        WHERE mac.ref_services_sku_in_record_id = p_services_sku

          AND mac.is_root = true

          AND mac.in_record_id <> p_exclude_record_id

        LIMIT 1;

    END IF;



    IF v_root_table_id IS NULL THEN

        -- Trigger already checks root existence, but keep function strong.

        RAISE EXCEPTION

            'Access config invalid: services_sku % has no root configured.',

            p_services_sku;

    END IF;



    ------------------------------------------------------------------

    -- 4) Validate connectivity (only for non-root records)

    --     root_table -> ... -> p_to_table must exist

    ------------------------------------------------------------------

    IF p_is_root IS NOT TRUE THEN



        WITH RECURSIVE edges AS (

            SELECT

                mn.ref_master_table_in_record_id AS from_table_id,

                mn.ref_master_table_in_record_id_connected     AS to_table_id

            FROM public.master_node mn

            WHERE mn.ref_master_table_in_record_id_connected IS NOT NULL

        ),

        walk AS (

            SELECT

                v_root_table_id::bigint AS current_table_id,

                ARRAY[v_root_table_id::bigint] AS path

            UNION ALL

            SELECT

                e.to_table_id,

                w.path || e.to_table_id

            FROM walk w

            JOIN edges e

              ON e.from_table_id = w.current_table_id

            WHERE NOT (e.to_table_id = ANY(w.path))   -- prevent cycles

        )

        SELECT EXISTS (

            SELECT 1

            FROM walk

            WHERE current_table_id = p_to_table

        )

        INTO v_has_path;



        IF v_has_path IS NOT TRUE THEN

            RAISE EXCEPTION

                'Access chain invalid: services_sku % root_table % cannot reach target_table % via master_node links.',

                p_services_sku, v_root_table_id, p_to_table;

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- 5) Optional: admin restricted protection

    ------------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.master_table mt

        WHERE mt.in_record_id = p_to_table

          AND COALESCE(mt.admin_restricted, false) = true

    ) THEN

        RAISE EXCEPTION

            'Access forbidden: master_table % is admin_restricted and cannot be part of SKU access chain.',

            p_to_table;

    END IF;



END;

$function$