CREATE OR REPLACE FUNCTION public.ac_requests_to_data_sync_access_control_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$

BEGIN



    IF TG_OP = 'INSERT' THEN



        PERFORM public.ac_self_child_update_master_access_wrapper(

            NEW.ref_master_table_in_record_id::bigint,

            NEW.ref_master_key_in_record_id::bigint

        );



        RETURN NEW;



    ELSIF TG_OP = 'UPDATE' THEN



        IF OLD.ref_master_table_in_record_id IS DISTINCT FROM NEW.ref_master_table_in_record_id

           OR OLD.ref_master_key_in_record_id IS DISTINCT FROM NEW.ref_master_key_in_record_id THEN



            PERFORM public.ac_self_child_update_master_access_wrapper(

                OLD.ref_master_table_in_record_id::bigint,

                OLD.ref_master_key_in_record_id::bigint

            );



            PERFORM public.ac_self_child_update_master_access_wrapper(

                NEW.ref_master_table_in_record_id::bigint,

                NEW.ref_master_key_in_record_id::bigint

            );



        END IF;



        RETURN NEW;



    ELSIF TG_OP = 'DELETE' THEN



        PERFORM public.ac_self_child_update_master_access_wrapper(

            OLD.ref_master_table_in_record_id::bigint,

            OLD.ref_master_key_in_record_id::bigint

        );



        RETURN OLD;



    END IF;



    RETURN NULL;

END;

$function$