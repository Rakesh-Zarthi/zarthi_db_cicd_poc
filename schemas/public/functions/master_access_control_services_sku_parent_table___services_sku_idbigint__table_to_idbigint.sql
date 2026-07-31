CREATE OR REPLACE FUNCTION public.master_access_control_services_sku_parent_table(_services_sku_id bigint, _table_to_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

DECLARE

    v_from_id bigint;

BEGIN

    SELECT a1.ref_master_table_in_record_id_from

    INTO v_from_id

    FROM (

        (

            SELECT

                m1.ref_services_sku_in_record_id,

                m1.ref_master_table_in_record_id_from

            FROM public.master_table_access_control_services_sku m1

            WHERE m1.ref_services_sku_in_record_id = _services_sku_id

              AND m1.ref_master_table_in_record_id_to <> _table_to_id

              AND m1.ref_master_table_in_record_id_from IS NOT NULL

        )

        INTERSECT

        (

            SELECT DISTINCT

                m1.ref_services_sku_in_record_id,

                mn.ref_master_table_in_record_id::bigint AS ref_master_table_in_record_id_from

            FROM public.master_table_access_control_services_sku m1

            JOIN public.master_node mn

              ON m1.ref_master_table_in_record_id_to = mn.ref_master_table_in_record_id_connected

            WHERE m1.ref_services_sku_in_record_id = _services_sku_id

              AND m1.ref_master_table_in_record_id_to = _table_to_id

        )

    ) a1

    LIMIT 1;



    RETURN v_from_id;

END;

$function$