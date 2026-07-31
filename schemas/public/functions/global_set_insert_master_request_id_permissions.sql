CREATE OR REPLACE FUNCTION public.global_set_insert_master_request_id_permissions()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    --------------------------------------------------

    -- INSERT

    --------------------------------------------------

    IF TG_OP = 'INSERT' THEN

        PERFORM public.ac_update_master_table_insert_master_request_id_permissions(

            n.ref_master_table_in_record_id

        )

        FROM new_rows n;



    --------------------------------------------------

    -- DELETE

    --------------------------------------------------

    ELSIF TG_OP = 'DELETE' THEN

        PERFORM public.ac_update_master_table_insert_master_request_id_permissions(

            o.ref_master_table_in_record_id

        )

        FROM old_rows o;



    --------------------------------------------------

    -- UPDATE (only when request changes)

    --------------------------------------------------

    ELSE

        PERFORM public.ac_update_master_table_insert_master_request_id_permissions(

            n.ref_master_table_in_record_id

        )

        FROM new_rows n

        JOIN old_rows o

          ON n.in_record_id = o.in_record_id

         AND n.ref_requests_in_record_id

             IS DISTINCT FROM o.ref_requests_in_record_id;

    END IF;



    RETURN NULL;

END;

$function$