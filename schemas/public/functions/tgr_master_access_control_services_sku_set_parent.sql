CREATE OR REPLACE FUNCTION public.tgr_master_access_control_services_sku_set_parent()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

DECLARE

    v_from_id bigint;

BEGIN

    -- Root rows must not have parent

    IF NEW.is_root THEN

        NEW.ref_master_table_in_record_id_from := NULL;

        RETURN NEW;

    END IF;



    -- Only compute if parent is NULL (avoid overwriting manually set value)

    IF NEW.ref_master_table_in_record_id_from IS NULL THEN



        SELECT a1.ref_master_table_in_record_id_from

        INTO v_from_id

        FROM (

            (

                SELECT

                    m1.ref_services_sku_in_record_id,

                    m1.ref_master_table_in_record_id_from

                FROM public.master_table_access_control_services_sku m1

                WHERE m1.ref_services_sku_in_record_id = NEW.ref_services_sku_in_record_id

                  AND m1.ref_master_table_in_record_id_to <> NEW.ref_master_table_in_record_id_to

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

                WHERE m1.ref_services_sku_in_record_id = NEW.ref_services_sku_in_record_id

                  AND m1.ref_master_table_in_record_id_to = NEW.ref_master_table_in_record_id_to

            )

        ) a1

        LIMIT 1;



        IF v_from_id IS NOT NULL THEN

            NEW.ref_master_table_in_record_id_from := v_from_id;

        END IF;



    END IF;



    RETURN NEW;

END;

$function$