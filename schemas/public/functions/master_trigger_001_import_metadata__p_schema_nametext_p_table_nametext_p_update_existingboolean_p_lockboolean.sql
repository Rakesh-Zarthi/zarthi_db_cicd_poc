CREATE OR REPLACE FUNCTION public.master_trigger_001_import_metadata(p_schema_name text, p_table_name text, p_update_existing boolean DEFAULT true, p_lock boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$



DECLARE



    ----------------------------------------------------------------

    -- Security

    ----------------------------------------------------------------

    v_user text := current_user;

    v_actor_uuid uuid;



    ----------------------------------------------------------------

    -- System write bypass control

    ----------------------------------------------------------------

    v_prev_system_write text;



    ----------------------------------------------------------------

    -- Inputs

    ----------------------------------------------------------------

    v_schema text;

    v_table text;



    ----------------------------------------------------------------

    -- Metadata IDs

    ----------------------------------------------------------------

    v_table_id bigint;

    v_mt_master_trigger_id bigint;



    ----------------------------------------------------------------

    -- Counters

    ----------------------------------------------------------------

    v_inserted int := 0;

    v_updated int := 0;

    v_deleted int := 0;



    ----------------------------------------------------------------

    -- UPSERT detection

    ----------------------------------------------------------------

    v_was_inserted boolean;



    ----------------------------------------------------------------

    -- Loop record

    ----------------------------------------------------------------

    rec record;



    ----------------------------------------------------------------

    -- Extracted values

    ----------------------------------------------------------------

    v_trigger_api_name text;

    v_events jsonb;

    v_timing text;

    v_level text;

    v_enabled boolean;

    v_when text;

    v_columns text[];

    v_columns_dropdown public."_dropdown";



BEGIN



    ----------------------------------------------------------------

    -- Permission check

    ----------------------------------------------------------------

    IF v_user NOT IN ('postgres','admin2','admin','superuser') THEN

        RAISE EXCEPTION 'Permission denied';

    END IF;



    ----------------------------------------------------------------

    -- Save current system_write state

    ----------------------------------------------------------------

    v_prev_system_write :=

        current_setting('app.system_write', true);



    ----------------------------------------------------------------

    -- Enable system write bypass

    ----------------------------------------------------------------

    PERFORM set_config('app.system_write','true',true);



    ----------------------------------------------------------------

    -- Normalize inputs

    ----------------------------------------------------------------

    v_schema := lower(trim(p_schema_name));

    v_table := lower(trim(p_table_name));



    IF v_schema IS NULL OR v_table IS NULL THEN

        RAISE EXCEPTION 'Schema and table required';

    END IF;



    ----------------------------------------------------------------

    -- Actor UUID

    ----------------------------------------------------------------

    v_actor_uuid :=

        COALESCE(

            NULLIF(current_setting('app.CURRENT_USER_ID',true),'')::uuid,

            '5c58b64f-e717-4c8c-a971-170acf7a45e7'

        );



    ----------------------------------------------------------------

    -- Lock metadata table

    ----------------------------------------------------------------

    IF p_lock THEN



        LOCK TABLE public.master_trigger

        IN SHARE ROW EXCLUSIVE MODE;



        PERFORM pg_advisory_xact_lock(

            hashtext(v_schema||'.'||v_table||'.trigger.sync')

        );



    END IF;



    ----------------------------------------------------------------

    -- Resolve master_table ID

    ----------------------------------------------------------------

    SELECT in_record_id

    INTO v_table_id

    FROM public.master_table

    WHERE table_api_name = v_table

    AND "schema" = v_schema;



    IF v_table_id IS NULL THEN

        RAISE EXCEPTION 'Table not registered: %.%',v_schema,v_table;

    END IF;



    ----------------------------------------------------------------

    -- Resolve master_trigger metadata ID

    ----------------------------------------------------------------

    SELECT in_record_id

    INTO v_mt_master_trigger_id

    FROM public.master_table

    WHERE table_api_name='master_trigger'

    AND "schema"='public';



    ----------------------------------------------------------------

    -- Snapshot physical triggers

    ----------------------------------------------------------------

    DROP TABLE IF EXISTS tmp_physical_triggers;

    CREATE TEMP TABLE tmp_physical_triggers

    ON COMMIT DROP

    AS

    SELECT



        t.tgname,

        t.tgrelid,

        t.tgtype,

        t.tgenabled,

        t.tgattr,



        p.proname function_name,

        pn.nspname function_schema,



        pg_get_triggerdef(t.oid,true) definition,



        ROW_NUMBER() OVER(ORDER BY t.tgname) execution_order



    FROM pg_trigger t

    JOIN pg_class c ON c.oid=t.tgrelid

    JOIN pg_namespace n ON n.oid=c.relnamespace

    JOIN pg_proc p ON p.oid=t.tgfoid

    JOIN pg_namespace pn ON pn.oid=p.pronamespace

    WHERE NOT t.tgisinternal

    AND n.nspname=v_schema

    AND c.relname=v_table;



    ----------------------------------------------------------------

    -- UPSERT LOOP

    ----------------------------------------------------------------

    FOR rec IN SELECT * FROM tmp_physical_triggers LOOP



        v_trigger_api_name := rec.tgname;



        ----------------------------------------------------------------

        -- Timing

        ----------------------------------------------------------------

        v_timing :=

        CASE

            WHEN (rec.tgtype & 2)<>0 THEN 'BEFORE'

            WHEN (rec.tgtype & 64)<>0 THEN 'INSTEAD OF'

            ELSE 'AFTER'

        END;



        ----------------------------------------------------------------

        -- Level

        ----------------------------------------------------------------

        v_level :=

        CASE

            WHEN (rec.tgtype & 1)<>0 THEN 'ROW'

            ELSE 'STATEMENT'

        END;



        ----------------------------------------------------------------

        -- Events

        ----------------------------------------------------------------

        SELECT jsonb_agg(e)

        INTO v_events

        FROM (

            VALUES

            (CASE WHEN (rec.tgtype & 4)<>0 THEN 'INSERT' END),

            (CASE WHEN (rec.tgtype & 8)<>0 THEN 'DELETE' END),

            (CASE WHEN (rec.tgtype & 16)<>0 THEN 'UPDATE' END),

            (CASE WHEN (rec.tgtype & 32)<>0 THEN 'TRUNCATE' END)

        ) x(e)

        WHERE e IS NOT NULL;



        v_events := COALESCE(v_events,'[]'::jsonb);



        ----------------------------------------------------------------

        -- Enabled

        ----------------------------------------------------------------

        v_enabled := rec.tgenabled='O';



        ----------------------------------------------------------------

        -- WHEN extraction safe

        ----------------------------------------------------------------

        v_when :=

        CASE

            WHEN rec.definition LIKE '%WHEN (%'

            THEN substring(rec.definition FROM 'WHEN \((.*)\) EXECUTE')

            ELSE NULL

        END;



        ----------------------------------------------------------------

        -- Columns

        ----------------------------------------------------------------

        SELECT array_agg(attname ORDER BY attnum)

        INTO v_columns

        FROM pg_attribute

        WHERE attrelid=rec.tgrelid

        AND attnum=ANY(rec.tgattr)

        AND attnum>0;



        v_columns := COALESCE(v_columns,ARRAY[]::text[]);

        v_columns_dropdown := v_columns::public."_dropdown";



        ----------------------------------------------------------------

        -- ENTERPRISE UPSERT WITH SAFE DETECTION

        ----------------------------------------------------------------

        INSERT INTO public.master_trigger(



            trigger_api_name,

            trigger_name,

            ref_master_table_in_record_id,



            trigger_timing,

            trigger_level,

            trigger_events,



            trigger_function_schema,

            trigger_function_name,



            trigger_columns,

            when_expression,



            enabled,

            execution_order,



            description,



            in_record_name,

            in_ref_master_table,



            in_ref_added_user_uuid,

            in_ref_modified_user_uuid,



            in_added_time,

            in_modified_time



        )

        VALUES(



            v_trigger_api_name,

            v_trigger_api_name,

            v_table_id,



            v_timing,

            v_level,

            v_events,



            rec.function_schema,

            rec.function_name,



            v_columns_dropdown,

            v_when,



            v_enabled,

            rec.execution_order,



            rec.definition,



            format('meta.master_trigger.%s.%s.%s',

            v_schema,v_table,v_trigger_api_name),



            v_mt_master_trigger_id,



            v_actor_uuid,

            v_actor_uuid,



            clock_timestamp(),

            clock_timestamp()



        )



        ON CONFLICT (ref_master_table_in_record_id,trigger_api_name)



        DO UPDATE SET



            trigger_name=EXCLUDED.trigger_name,

            trigger_timing=EXCLUDED.trigger_timing,

            trigger_level=EXCLUDED.trigger_level,

            trigger_events=EXCLUDED.trigger_events,



            trigger_function_schema=EXCLUDED.trigger_function_schema,

            trigger_function_name=EXCLUDED.trigger_function_name,



            trigger_columns=EXCLUDED.trigger_columns,

            when_expression=EXCLUDED.when_expression,



            enabled=EXCLUDED.enabled,

            execution_order=EXCLUDED.execution_order,



            description=EXCLUDED.description,



            in_ref_modified_user_uuid=v_actor_uuid,

            in_modified_time=clock_timestamp()



        RETURNING (xmax=0) INTO v_was_inserted;



        IF v_was_inserted THEN

            v_inserted := v_inserted + 1;

        ELSE

            v_updated := v_updated + 1;

        END IF;



    END LOOP;



    ----------------------------------------------------------------

    -- Orphan cleanup

    ----------------------------------------------------------------

    DELETE FROM public.master_trigger mt

    WHERE mt.ref_master_table_in_record_id=v_table_id

    AND NOT EXISTS(

        SELECT 1 FROM tmp_physical_triggers t

        WHERE t.tgname=mt.trigger_api_name

    );



    GET DIAGNOSTICS v_deleted = ROW_COUNT;



    ----------------------------------------------------------------

    -- Restore system_write

    ----------------------------------------------------------------

    PERFORM set_config(

        'app.system_write',

        COALESCE(v_prev_system_write,'false'),

        true

    );



    ----------------------------------------------------------------

    -- Return result

    ----------------------------------------------------------------

    RETURN jsonb_build_object(



        'schema',v_schema,

        'table',v_table,



        'inserted',v_inserted,

        'updated',v_updated,

        'deleted',v_deleted,



        'status','complete'



    );



END;

$function$