CREATE OR REPLACE FUNCTION public.global_tgr_child_master_table_access_control()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    v_users_changed boolean := false;

    v_requests_changed boolean := false;



BEGIN



    ------------------------------------------------------------

    -- INSERT

    ------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        v_users_changed :=

            NEW.in_ref_master_users_id IS NOT NULL;



        v_requests_changed :=

            NEW.in_ref_master_request_id IS NOT NULL;



        IF v_users_changed OR v_requests_changed THEN



            PERFORM public.ac_child_master_table_access_control_wrapper(

                NEW.in_ref_master_table,

                NEW.in_record_id,

                v_users_changed,

                v_requests_changed

            );



        END IF;



        RETURN NEW;



    END IF;



    ------------------------------------------------------------

    -- DELETE

    ------------------------------------------------------------

    IF TG_OP = 'DELETE' THEN



        PERFORM public.ac_child_master_table_access_control_wrapper(

            OLD.in_ref_master_table,

            OLD.in_record_id,

            true,

            true

        );



        RETURN OLD;



    END IF;



    ------------------------------------------------------------

    -- UPDATE

    ------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN



        v_users_changed :=

            NEW.in_ref_master_users_id

            IS DISTINCT FROM OLD.in_ref_master_users_id;



        v_requests_changed :=

            NEW.in_ref_master_request_id

            IS DISTINCT FROM OLD.in_ref_master_request_id;



        ------------------------------------------------------------

        -- propagate OLD first (remove stale inheritance)

        ------------------------------------------------------------

        IF v_users_changed OR v_requests_changed THEN



            PERFORM public.ac_child_master_table_access_control_wrapper(

                OLD.in_ref_master_table,

                OLD.in_record_id,

                v_users_changed,

                v_requests_changed

            );



        END IF;



        ------------------------------------------------------------

        -- propagate NEW second (apply new inheritance)

        ------------------------------------------------------------

        IF v_users_changed OR v_requests_changed THEN



            PERFORM public.ac_child_master_table_access_control_wrapper(

                NEW.in_ref_master_table,

                NEW.in_record_id,

                v_users_changed,

                v_requests_changed

            );



        END IF;



        RETURN NEW;



    END IF;



    RETURN NULL;



END;

$function$