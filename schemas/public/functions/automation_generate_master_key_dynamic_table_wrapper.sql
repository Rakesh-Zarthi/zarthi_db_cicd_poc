CREATE OR REPLACE FUNCTION public.automation_generate_master_key_dynamic_table_wrapper()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_table_api        text;

    v_master_table_id  bigint;

    v_json             jsonb;

BEGIN





    ------------------------------------------------------------------

    -- 1∩╕ÅΓâú Resolve table_api_name AND master_table_id

    ------------------------------------------------------------------

    SELECT mt.table_api_name,

           mt.in_record_id

    INTO   v_table_api,

           v_master_table_id

    FROM public.master_table mt

    WHERE lower(mt.table_api_name) = lower(TG_TABLE_NAME)

    LIMIT 1;



    IF v_table_api IS NULL OR v_master_table_id IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î master_table entry missing for table "%".',

            TG_TABLE_NAME;

    END IF;



    ------------------------------------------------------------------

    -- 2∩╕ÅΓâú Master-key generation (ONLY if configured)

    ------------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM public.master_node mn

        WHERE mn.ref_master_table_in_record_id = v_master_table_id

          AND COALESCE(mn.is_master_key, FALSE) = TRUE

    ) THEN

        ------------------------------------------------------------------

        -- Build JSON from NEW row

        ------------------------------------------------------------------

        v_json := to_jsonb(NEW);



        ------------------------------------------------------------------

        -- JSON MODE (primary)

        ------------------------------------------------------------------

        NEW.in_record_name :=

            public.automation_generate_master_key_for_dynamic_table(

                v_table_api,

                v_json,

                FALSE

            );



        ------------------------------------------------------------------

        -- SQL MODE fallback

        ------------------------------------------------------------------

        IF NEW.in_record_name IS NULL

           OR trim(NEW.in_record_name) = '' THEN



            NEW.in_record_name :=

                public.automation_generate_master_key_for_dynamic_table(

                    v_table_api,

                    jsonb_build_object('master_id', NEW.in_record_id),

                    FALSE

                );

        END IF;

    END IF;



    ------------------------------------------------------------------

    -- 3∩╕ÅΓâú ≡ƒöÆ FINAL, NON-NEGOTIABLE SECURITY ANCHOR

    -- This MUST be last and MUST override all other triggers

    ------------------------------------------------------------------

    NEW.in_ref_master_table := v_master_table_id;



    RETURN NEW;

END;

$function$