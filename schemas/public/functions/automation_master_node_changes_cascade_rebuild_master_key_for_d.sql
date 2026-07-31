CREATE OR REPLACE FUNCTION public.automation_master_node_changes_cascade_rebuild_master_key_for_d()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_fk_old bigint;

    v_fk_new bigint;

    v_api_old text;

    v_api_new text;

BEGIN

    IF TG_OP <> 'UPDATE' THEN

        RETURN NEW;

    END IF;



    IF current_setting('app.rebuild_masterkeys', true) = 'on' THEN

        RETURN NEW;

    END IF;



    IF NOT (

           NEW.node_label IS DISTINCT FROM OLD.node_label

        OR NEW.pre_text_master_key IS DISTINCT FROM OLD.pre_text_master_key

        OR NEW.post_text_master_key IS DISTINCT FROM OLD.post_text_master_key

        OR NEW.master_key_sequence IS DISTINCT FROM OLD.master_key_sequence

        OR NEW.is_master_key IS DISTINCT FROM OLD.is_master_key

        OR NEW.ref_master_table_in_record_id IS DISTINCT FROM OLD.ref_master_table_in_record_id

    ) THEN

        RETURN NEW;

    END IF;



    v_fk_old := OLD.ref_master_table_in_record_id;

    v_fk_new := NEW.ref_master_table_in_record_id;



    PERFORM set_config('app.rebuild_masterkeys', 'on', true);



    BEGIN

        IF v_fk_old IS NOT NULL THEN

            SELECT table_api_name INTO v_api_old

            FROM public.master_table

            WHERE in_record_id = v_fk_old;



            IF v_api_old IS NOT NULL THEN

                PERFORM public.automation_regenerate_master_keys_for_dynamic_table(v_api_old);

            END IF;

        END IF;



        IF v_fk_new IS NOT NULL

           AND v_fk_new IS DISTINCT FROM v_fk_old THEN



            SELECT table_api_name INTO v_api_new

            FROM public.master_table

            WHERE in_record_id = v_fk_new;



            IF v_api_new IS NOT NULL THEN

                PERFORM public.automation_regenerate_master_keys_for_dynamic_table(v_api_new);

            END IF;

        END IF;



    EXCEPTION WHEN OTHERS THEN

        PERFORM set_config('app.rebuild_masterkeys', 'off', true);

        RAISE;

    END;



    PERFORM set_config('app.rebuild_masterkeys', 'off', true);

    RETURN NEW;

END;

$function$