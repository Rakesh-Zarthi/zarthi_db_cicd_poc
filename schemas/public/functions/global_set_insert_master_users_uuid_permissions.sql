CREATE OR REPLACE FUNCTION public.global_set_insert_master_users_uuid_permissions()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN



    ------------------------------------------------------------------

    -- INSERT

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        PERFORM public.ac_update_master_table_insert_master_users_uuid_permissions(

            ac.ref_master_table_in_record_id_to

        )

        FROM new_rows n

        JOIN requests_services rs

          ON rs.ref_requests_record_id = n.in_record_id

        JOIN master_table_access_control_services_sku ac

          ON ac.ref_services_sku_in_record_id = rs.ref_services_sku

         AND ac.permission @> ARRAY['Insert']::dropdown[];



    ------------------------------------------------------------------

    -- DELETE

    ------------------------------------------------------------------

    ELSIF TG_OP = 'DELETE' THEN



        PERFORM public.ac_update_master_table_insert_master_users_uuid_permissions(

            ac.ref_master_table_in_record_id_to

        )

        FROM old_rows o

        JOIN requests_services rs

          ON rs.ref_requests_record_id = o.in_record_id

        JOIN master_table_access_control_services_sku ac

          ON ac.ref_services_sku_in_record_id = rs.ref_services_sku

         AND ac.permission @> ARRAY['Insert']::dropdown[];



    ------------------------------------------------------------------

    -- UPDATE (owner delta only)

    ------------------------------------------------------------------

    ELSE



        PERFORM public.ac_update_master_table_insert_master_users_uuid_permissions(

            ac.ref_master_table_in_record_id_to

        )

        FROM new_rows n

        JOIN old_rows o

          ON n.in_record_id = o.in_record_id

         AND n.owner IS DISTINCT FROM o.owner

        JOIN requests_services rs

          ON rs.ref_requests_record_id = n.in_record_id

        JOIN master_table_access_control_services_sku ac

          ON ac.ref_services_sku_in_record_id = rs.ref_services_sku

         AND ac.permission @> ARRAY['Insert']::dropdown[];



    END IF;



    RETURN NULL;

END;

$function$