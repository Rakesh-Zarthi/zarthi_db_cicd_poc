CREATE OR REPLACE FUNCTION public.automation_master_node_rebuild_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_old_table_id bigint;

    v_new_table_id bigint;

BEGIN

    ------------------------------------------------------------------

    -- Skip during bulk/system writes

    ------------------------------------------------------------------

    IF current_setting('app.system_write', true) = 'true' THEN

        RETURN COALESCE(NEW, OLD);

    END IF;



    v_old_table_id := OLD.ref_master_table_in_record_id;

    v_new_table_id := NEW.ref_master_table_in_record_id;



    ------------------------------------------------------------------

    -- INSERT

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN

        IF v_new_table_id IS NOT NULL

           AND COALESCE(NEW.is_master_key, FALSE) = TRUE THEN

            PERFORM public.automation_rebuild_master_key_trigger_dual_swap(

                v_new_table_id

            );

        END IF;



    ------------------------------------------------------------------

    -- UPDATE

    ------------------------------------------------------------------

    ELSIF TG_OP = 'UPDATE' THEN

        -- Node moved between tables ΓåÆ rebuild both

        IF v_old_table_id IS DISTINCT FROM v_new_table_id THEN

            IF v_old_table_id IS NOT NULL THEN

                PERFORM public.automation_rebuild_master_key_trigger_dual_swap(

                    v_old_table_id

                );

            END IF;



            IF v_new_table_id IS NOT NULL THEN

                PERFORM public.automation_rebuild_master_key_trigger_dual_swap(

                    v_new_table_id

                );

            END IF;



        -- Same table, master-key semantics changed

        ELSIF (

               OLD.node_api_name IS DISTINCT FROM NEW.node_api_name

            OR COALESCE(OLD.is_master_key, FALSE)

               IS DISTINCT FROM COALESCE(NEW.is_master_key, FALSE)

            OR COALESCE(OLD.master_key_sequence, 0)

               IS DISTINCT FROM COALESCE(NEW.master_key_sequence, 0)

            OR COALESCE(OLD.is_mandatory, FALSE)

               IS DISTINCT FROM COALESCE(NEW.is_mandatory, FALSE)

            OR COALESCE(OLD.pre_text_master_key, '')

               IS DISTINCT FROM COALESCE(NEW.pre_text_master_key, '')

            OR COALESCE(OLD.post_text_master_key, '')

               IS DISTINCT FROM COALESCE(NEW.post_text_master_key, '')

        ) THEN

            IF v_new_table_id IS NOT NULL THEN

                PERFORM public.automation_rebuild_master_key_trigger_dual_swap(

                    v_new_table_id

                );

            END IF;

        END IF;



    ------------------------------------------------------------------

    -- DELETE

    ------------------------------------------------------------------

    ELSIF TG_OP = 'DELETE' THEN

        IF v_old_table_id IS NOT NULL

           AND COALESCE(OLD.is_master_key, FALSE) = TRUE THEN

            PERFORM public.automation_rebuild_master_key_trigger_dual_swap(

                v_old_table_id

            );

        END IF;

    END IF;



    RETURN COALESCE(NEW, OLD);

END;

$function$