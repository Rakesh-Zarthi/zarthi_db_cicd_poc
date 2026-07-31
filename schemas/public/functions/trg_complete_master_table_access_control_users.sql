CREATE OR REPLACE FUNCTION public.trg_complete_master_table_access_control_users()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_table_id     int;

    v_in_record_id bigint;

BEGIN

    ------------------------------------------------------------------

    -- DELETE: Recalculate for OLD table reference

    ------------------------------------------------------------------

    IF TG_OP = 'DELETE' THEN



        FOR v_in_record_id IN

            SELECT in_record_id

            FROM public.master_key

            WHERE in_ref_master_table = OLD.ref_master_table_in_record_id_to

        LOOP

            PERFORM public.ac_self_and_child_update_master_table_access_control(

                OLD.ref_master_table_in_record_id_to,

                v_in_record_id

            );

        END LOOP;



        RETURN OLD;

    END IF;



    ------------------------------------------------------------------

    -- INSERT: Recalculate for NEW table reference

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        FOR v_in_record_id IN

            SELECT in_record_id

            FROM public.master_key

            WHERE in_ref_master_table = NEW.ref_master_table_in_record_id_to

        LOOP

            PERFORM public.ac_self_and_child_update_master_table_access_control(

                NEW.ref_master_table_in_record_id_to,

                v_in_record_id

            );

        END LOOP;



        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- UPDATE

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN



        -- If table reference changed, recalc OLD first

        IF OLD.ref_master_table_in_record_id_to

           IS DISTINCT FROM NEW.ref_master_table_in_record_id_to THEN



            FOR v_in_record_id IN

                SELECT in_record_id

                FROM public.master_key

                WHERE in_ref_master_table = OLD.ref_master_table_in_record_id_to

            LOOP

                PERFORM public.ac_self_and_child_update_master_table_access_control(

                    OLD.ref_master_table_in_record_id_to,

                    v_in_record_id

                );

            END LOOP;

        END IF;



        -- Always recalc NEW table reference

        FOR v_in_record_id IN

            SELECT in_record_id

            FROM public.master_key

            WHERE in_ref_master_table = NEW.ref_master_table_in_record_id_to

        LOOP

            PERFORM public.ac_self_and_child_update_master_table_access_control(

                NEW.ref_master_table_in_record_id_to,

                v_in_record_id

            );

        END LOOP;



        RETURN NEW;

    END IF;



    RETURN NULL;

END;

$function$