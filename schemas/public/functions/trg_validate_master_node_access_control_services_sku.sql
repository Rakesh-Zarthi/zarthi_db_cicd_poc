CREATE OR REPLACE FUNCTION public.trg_validate_master_node_access_control_services_sku()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_parent_table_id    bigint;

    v_node_table_id      bigint;

    v_parent_permissions public._dropdown;

    v_perm               public.dropdown;

    v_perm_dedup         text[];

BEGIN

    ------------------------------------------------------------------

    -- 0) Sanity checks

    ------------------------------------------------------------------

    IF NEW.ref_master_table_access_control_services_sku_in_record_id IS NULL THEN

        RAISE EXCEPTION 'ref_master_table_access_control_services_sku_in_record_id cannot be NULL';

    END IF;



    IF NEW.ref_master_node_in_record_id_to IS NULL THEN

        RAISE EXCEPTION 'ref_master_node_in_record_id_to cannot be NULL';

    END IF;



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

    -- 2) Load parent table_id + permission set

    ------------------------------------------------------------------

    SELECT

        mac.ref_master_table_in_record_id_to::bigint,

        mac.permission

    INTO

        v_parent_table_id,

        v_parent_permissions

    FROM public.master_table_access_control_services_sku mac

    WHERE mac.in_record_id = NEW.ref_master_table_access_control_services_sku_in_record_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid parent access control id %, no record found in master_table_access_control_services_sku',

            NEW.ref_master_table_access_control_services_sku_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- 3) Load node's table_id

    ------------------------------------------------------------------

    SELECT mn.ref_master_table_in_record_id::bigint

    INTO v_node_table_id

    FROM public.master_node mn

    WHERE mn.in_record_id = NEW.ref_master_node_in_record_id_to;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid master_node id %, no record found in master_node',

            NEW.ref_master_node_in_record_id_to;

    END IF;



    ------------------------------------------------------------------

    -- 4) Node must belong to same master_table as parent access record

    ------------------------------------------------------------------

    IF v_node_table_id IS DISTINCT FROM v_parent_table_id THEN

        RAISE EXCEPTION

            'Node access invalid: node % belongs to master_table %, but parent access control % belongs to master_table %',

            NEW.ref_master_node_in_record_id_to,

            v_node_table_id,

            NEW.ref_master_table_access_control_services_sku_in_record_id,

            v_parent_table_id;

    END IF;



    ------------------------------------------------------------------

    -- 5) Node permissions must be subset of parent table permissions

    ------------------------------------------------------------------

    FOREACH v_perm IN ARRAY NEW.permission

    LOOP

        IF NOT (v_perm = ANY(v_parent_permissions)) THEN

            RAISE EXCEPTION

                'Node access invalid: permission % is not allowed because parent table permissions do not include it (parent access control %)',

                v_perm,

                NEW.ref_master_table_access_control_services_sku_in_record_id;

        END IF;

    END LOOP;



    RETURN NEW;

END;

$function$