CREATE OR REPLACE FUNCTION public.automation_delete_table_node()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_table_name  text;

    v_column_name text;

    v_exists      boolean;

    v_sql         text;

    v_seq_name    text;

BEGIN

    ----------------------------------------------------------------------

    -- 1∩╕ÅΓâú Resolve parent form table using new FK: ref_master_table_in_record_id

    ----------------------------------------------------------------------

    SELECT mt.table_api_name

    INTO v_table_name

    FROM public.master_table mt

    WHERE mt.in_record_id = OLD.ref_master_table_in_record_id

    LIMIT 1;



    IF v_table_name IS NULL THEN

        RAISE NOTICE

            'ΓÜá∩╕Å No parent table found for node (in_record_id=%). Skipping column drop.',

            OLD.in_record_id;

        RETURN OLD;

    END IF;



    ----------------------------------------------------------------------

    -- 2∩╕ÅΓâú Normalize SQL column name

    ----------------------------------------------------------------------

    v_column_name :=

        lower(regexp_replace(trim(OLD.node_label), '[^a-zA-Z0-9_]', '_', 'g'));



    IF v_column_name = '' THEN

        RAISE NOTICE 'ΓÜá∩╕Å Invalid node label for node in_record_id=%', OLD.in_record_id;

        RETURN OLD;

    END IF;



    ----------------------------------------------------------------------

    -- 3∩╕ÅΓâú Prevent dropping protected/inherited core columns

    ----------------------------------------------------------------------

    IF v_column_name IN (

        'in_record_id','in_record_name','in_added_time','in_modified_time',

        'in_ref_added_user','in_ref_modified_user','in_ref_master_table',

        'owner','status','stage'

    ) THEN

        RAISE NOTICE

            '≡ƒÜ½ Protected column "%" cannot be deleted from "%". Skipped.',

            v_column_name, v_table_name;

        RETURN OLD;

    END IF;



    ----------------------------------------------------------------------

    -- 4∩╕ÅΓâú Check if physical SQL table exists

    ----------------------------------------------------------------------

    PERFORM 1

    FROM pg_class c

    JOIN pg_namespace n ON n.oid = c.relnamespace

    WHERE c.relname = v_table_name

      AND n.nspname = 'public';



    IF NOT FOUND THEN

        RAISE NOTICE 'ΓÜá∩╕Å Physical table "%" not found in schema. Skipping.', v_table_name;

        RETURN OLD;

    END IF;



    ----------------------------------------------------------------------

    -- 5∩╕ÅΓâú Check if column exists

    ----------------------------------------------------------------------

    SELECT EXISTS (

        SELECT 1

        FROM information_schema.columns

        WHERE table_schema='public'

          AND table_name=v_table_name

          AND column_name=v_column_name

    ) INTO v_exists;



    IF NOT v_exists THEN

        RAISE NOTICE 'Γä╣∩╕Å Column "%" does not exist in "%", skipping.', v_column_name, v_table_name;

        RETURN OLD;

    END IF;



    ----------------------------------------------------------------------

    -- 6∩╕ÅΓâú If master-key field ΓåÆ drop sequence after column removal

    ----------------------------------------------------------------------

    IF COALESCE(OLD.is_master_key, false) THEN

        v_seq_name := format('%s_%s_seq', v_table_name, v_column_name);

    END IF;



    ----------------------------------------------------------------------

    -- 7∩╕ÅΓâú Drop the column

    ----------------------------------------------------------------------

    v_sql := format(

        'ALTER TABLE public.%I DROP COLUMN IF EXISTS %I CASCADE;',

        v_table_name,

        v_column_name

    );



    EXECUTE v_sql;



    RAISE NOTICE '≡ƒùæ∩╕Å Column "%" dropped from table "%".', v_column_name, v_table_name;



    ----------------------------------------------------------------------

    -- 8∩╕ÅΓâú Drop associated sequence

    ----------------------------------------------------------------------

    IF v_seq_name IS NOT NULL THEN

        EXECUTE format('DROP SEQUENCE IF EXISTS public.%I;', v_seq_name);

        RAISE NOTICE '≡ƒùæ∩╕Å Dropped master-key sequence "%".', v_seq_name;

    END IF;



    ----------------------------------------------------------------------

    -- 9∩╕ÅΓâú Audit Log

    ----------------------------------------------------------------------

    BEGIN

        INSERT INTO public.security_events (

            attempted_user,

            table_name,

            operation,

            message,

            attempted_data,

            created_at

        )

        VALUES (

            current_user,

            v_table_name,

            'ALTER TABLE DROP COLUMN',

            format('Dropped column %I from table %I', v_column_name, v_table_name),

            jsonb_build_object(

                'node_master_key', OLD.in_record_id,

                'ref_master_table_in_record_id', OLD.ref_master_table_in_record_id,

                'column_name', v_column_name,

                'was_master_key', OLD.is_master_key,

                'sequence_dropped', v_seq_name

            ),

            NOW()

        );

    EXCEPTION WHEN OTHERS THEN

        RAISE NOTICE 'ΓÜá∩╕Å Audit logging failed: %', SQLERRM;

    END;



    RETURN OLD;

END;

$function$