CREATE OR REPLACE FUNCTION public.trg_master_node_cascade_masterkey()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_table_api text;

    v_trigger_name text;

    v_exists boolean;

BEGIN

    -- 1∩╕ÅΓâú Identify which form (master_table) this node is connected to

    SELECT mt.table_api_name

    INTO v_table_api

    FROM public.master_table mt

    WHERE mt.master_key = COALESCE(NEW.ref_master_table_in_record_id_connected, OLD.ref_master_table_in_record_id_connected);



    -- 2∩╕ÅΓâú Skip if no linked table

    IF v_table_api IS NULL THEN

        RAISE NOTICE 'Γä╣∩╕Å No linked form table found for master_node change.';

        RETURN NULL;

    END IF;



    -- 3∩╕ÅΓâú Skip for system tables (safety)

    IF v_table_api IN ('master_table', 'master_node', 'master_key', 'data_logs', 'json_logs', 'security_events') THEN

        RAISE NOTICE '≡ƒÜ½ Skipping system table % for master_key trigger attachment.', v_table_api;

        RETURN NULL;

    END IF;



    -- 4∩╕ÅΓâú Check if masterkey trigger already exists

    SELECT EXISTS (

        SELECT 1

        FROM pg_trigger

        WHERE tgrelid = format('public.%I', v_table_api)::regclass

          AND tgname = format('trg_set_masterkey_%s', v_table_api)

    ) INTO v_exists;



    -- 5∩╕ÅΓâú If trigger missing, auto-attach

    IF NOT v_exists THEN

        BEGIN

            PERFORM public.fn_attach_masterkey_trigger(v_table_api);

            RAISE NOTICE 'Γ£à Auto-attached master key trigger for new form "%".', v_table_api;

        EXCEPTION WHEN OTHERS THEN

            RAISE WARNING 'ΓÜá∩╕Å Failed to attach master key trigger for "%": %', v_table_api, SQLERRM;

        END;

    END IF;



    -- 6∩╕ÅΓâú Cascade regeneration of all keys if nodes changed

    BEGIN

        PERFORM public.regenerate_all_master_keys(v_table_api);

        RAISE NOTICE '≡ƒöä Regenerated all master keys for table "%".', v_table_api;

    EXCEPTION WHEN OTHERS THEN

        RAISE WARNING 'ΓÜá∩╕Å Failed to regenerate master keys for "%": %', v_table_api, SQLERRM;

    END;



    RETURN NULL;

END;

$function$