CREATE OR REPLACE FUNCTION public.global_set_insert_master_request_id_permissions_from_requests_t()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

DECLARE

    r record;

BEGIN

    --------------------------------------------------

    -- INSERT

    --------------------------------------------------

    IF TG_OP = 'INSERT' THEN

        FOR r IN

            SELECT DISTINCT ref_master_table_in_record_id

            FROM new_rows

        LOOP

            PERFORM public.ac_update_master_table_insert_master_request_id_permissions(

                r.ref_master_table_in_record_id

            );

        END LOOP;



    --------------------------------------------------

    -- DELETE

    --------------------------------------------------

    ELSIF TG_OP = 'DELETE' THEN

        FOR r IN

            SELECT DISTINCT ref_master_table_in_record_id

            FROM old_rows

        LOOP

            PERFORM public.ac_update_master_table_insert_master_request_id_permissions(

                r.ref_master_table_in_record_id

            );

        END LOOP;



    --------------------------------------------------

    -- UPDATE

    --------------------------------------------------

    ELSE

        FOR r IN

            SELECT DISTINCT ref_master_table_in_record_id

            FROM (

                SELECT ref_master_table_in_record_id FROM new_rows

                UNION

                SELECT ref_master_table_in_record_id FROM old_rows

            ) s

        LOOP

            PERFORM public.ac_update_master_table_insert_master_request_id_permissions(

                r.ref_master_table_in_record_id

            );

        END LOOP;

    END IF;



    RETURN NULL;

END;

$function$