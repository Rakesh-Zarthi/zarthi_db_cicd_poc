CREATE OR REPLACE FUNCTION public.fn_regenerate_all_master_keys(_table_api text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_flag text := format('regen_%s_running', _table_api);

    v_sql  text;

    v_lock bigint := hashtext(_table_api);

BEGIN

    -- ≡ƒÜ½ Guard 1: Prevent same-session recursion

    IF current_setting(v_flag, true) = 'on' THEN

        RAISE NOTICE 'ΓÜá∩╕Å Recursion prevented for "%"', _table_api;

        RETURN;

    END IF;



    -- ≡ƒ¢æ Guard 2: Global lock (prevents concurrent regen for same table)

    IF NOT pg_try_advisory_lock(v_lock) THEN

        RAISE NOTICE 'ΓÅ│ Regeneration for "%" already running elsewhere, skipping.', _table_api;

        RETURN;

    END IF;



    PERFORM set_config(v_flag, 'on', false);



    BEGIN

        -- ≡ƒöü Actual regeneration

        v_sql := format(

            'UPDATE public.%I

             SET master_key = public.generate_dynamic_master_key(%L, master_id, true);',

            _table_api, _table_api

        );

        EXECUTE v_sql;



        RAISE NOTICE 'Γ£à Regenerated all master keys for table "%".', _table_api;



    EXCEPTION WHEN others THEN

        RAISE WARNING 'ΓÜá∩╕Å Regeneration failed for "%": %', _table_api, SQLERRM;

    END;



    -- ≡ƒº╣ Cleanup

    PERFORM set_config(v_flag, 'off', false);

    PERFORM pg_advisory_unlock(v_lock);



EXCEPTION WHEN others THEN

    PERFORM pg_advisory_unlock(v_lock);

    PERFORM set_config(v_flag, 'off', false);

    RAISE;

END;

$function$