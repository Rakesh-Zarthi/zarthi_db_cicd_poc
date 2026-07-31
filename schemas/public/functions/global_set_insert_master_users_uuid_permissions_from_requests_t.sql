CREATE OR REPLACE FUNCTION public.global_set_insert_master_users_uuid_permissions_from_requests_t()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN



    ------------------------------------------------------------------

    -- INSERT

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        PERFORM public.ac_update_master_table_insert_master_users_uuid_permissions(

            m.ref_master_table_in_record_id

        )

        FROM new_rows n

        JOIN public.requests_to_data m

          ON m.ref_requests_in_record_id = n.ref_requests_in_record_id;



    ------------------------------------------------------------------

    -- DELETE

    ------------------------------------------------------------------

    ELSIF TG_OP = 'DELETE' THEN



        PERFORM public.ac_update_master_table_insert_master_users_uuid_permissions(

            m.ref_master_table_in_record_id

        )

        FROM old_rows o

        JOIN public.requests_to_data m

          ON m.ref_requests_in_record_id = o.ref_requests_in_record_id;



    ------------------------------------------------------------------

    -- UPDATE (only when request link changes)

    ------------------------------------------------------------------

    ELSE



        PERFORM public.ac_update_master_table_insert_master_users_uuid_permissions(

            m.ref_master_table_in_record_id

        )

        FROM new_rows n

        JOIN old_rows o

          ON n.in_record_id = o.in_record_id

         AND n.ref_requests_in_record_id IS DISTINCT FROM o.ref_requests_in_record_id

        JOIN public.requests_to_data m

          ON m.ref_requests_in_record_id = n.ref_requests_in_record_id;



    END IF;



    RETURN NULL;

END;

$function$