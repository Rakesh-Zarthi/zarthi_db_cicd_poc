CREATE OR REPLACE FUNCTION public.automation_delete_table()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_table_name        text;

    v_user              text := current_user;

    v_oid               oid;

    v_row_count         bigint := 0;

    v_fk_sources        text;

    v_fk_targets        text;

    v_dependents        text;

    v_snapshot_cols     jsonb;

    v_sql               text;

BEGIN

    ----------------------------------------------------------------------

    -- 1. Normalize and validate identifier

    ----------------------------------------------------------------------

    v_table_name := lower(trim(OLD.table_api_name));



    IF v_table_name IS NULL OR v_table_name = '' THEN

        RAISE EXCEPTION 'Γ¥î Invalid table_api_name.';

    END IF;



    IF v_table_name !~ '^[a-z][a-z0-9_]*$' THEN

        RAISE EXCEPTION

        'Γ¥î Invalid table_api_name "%". Must match: ^[a-z][a-z0-9_]*$',

        OLD.table_api_name;

    END IF;



    IF length(v_table_name) > 63 THEN

        RAISE EXCEPTION 

            'Γ¥î table_api_name "%" exceeds PostgreSQL identifier limit (63 chars).',

            OLD.table_api_name;

    END IF;



    ----------------------------------------------------------------------

    -- 2. Admin-only enforcement

    ----------------------------------------------------------------------

    IF v_user NOT IN ('postgres','admin','superuser') THEN

        RAISE EXCEPTION 

            '≡ƒÜ½ Only admin/superuser may delete dynamic tables. User="%".', v_user;

    END IF;



    ----------------------------------------------------------------------

    -- 3. Protect core system tables

    ----------------------------------------------------------------------

    IF v_table_name IN (

        'master_key','master_table','master_node','users','requests',

        'actionables','actionables_execution_metadata','security_events',

        'data_logs_fields','data_logs_json'

    ) THEN

        RAISE EXCEPTION 

            '≡ƒÜ½ Table "%" is protected and cannot be deleted.', v_table_name;

    END IF;



    ----------------------------------------------------------------------

    -- 4. Check existence

    ----------------------------------------------------------------------

    SELECT c.oid

    INTO v_oid

    FROM pg_class c

    JOIN pg_namespace n ON n.oid=c.relnamespace

    WHERE c.relname = v_table_name

      AND n.nspname = 'public';



    IF v_oid IS NULL THEN

        RAISE NOTICE 'Γä╣∩╕Å Table "%" does not exist.', v_table_name;

        RETURN OLD;

    END IF;



    ----------------------------------------------------------------------

    -- 5. Advisory lock

    ----------------------------------------------------------------------

    PERFORM pg_advisory_xact_lock(hashtext(v_table_name));



    ----------------------------------------------------------------------

    -- 6. Block delete if table has rows

    ----------------------------------------------------------------------

    EXECUTE format('SELECT COUNT(*) FROM public.%I;', v_table_name)

    INTO v_row_count;



    IF v_row_count > 0 THEN

        RAISE EXCEPTION 

            '≡ƒÜ½ Cannot delete "%" because it contains % row(s).',

            v_table_name, v_row_count;

    END IF;



    ----------------------------------------------------------------------

    -- 7. Detect inbound FK constraints

    ----------------------------------------------------------------------

    SELECT string_agg(format('%I.%I', ns.nspname, rel.relname), ', ')

    INTO v_fk_sources

    FROM pg_constraint c

    JOIN pg_class rel ON rel.oid=c.conrelid

    JOIN pg_namespace ns ON ns.oid=rel.relnamespace

    WHERE c.confrelid = v_oid

      AND c.contype='f';



    IF v_fk_sources IS NOT NULL THEN

        RAISE EXCEPTION 

            '≡ƒÜ½ Cannot delete "%": referenced by foreign keys in: %',

            v_table_name, v_fk_sources;

    END IF;



    ----------------------------------------------------------------------

    -- 8. Detect outbound FKs

    ----------------------------------------------------------------------

    SELECT string_agg(format('%I.%I', ns.nspname, rel.relname), ', ')

    INTO v_fk_targets

    FROM pg_constraint c

    JOIN pg_class rel ON rel.oid=c.confrelid

    JOIN pg_namespace ns ON ns.oid=rel.relnamespace

    WHERE c.conrelid = v_oid

      AND c.contype='f';



    IF v_fk_targets IS NOT NULL THEN

        RAISE EXCEPTION 

            '≡ƒÜ½ Cannot delete "%": it contains FK references to: %',

            v_table_name, v_fk_targets;

    END IF;



    ----------------------------------------------------------------------

    -- 9. Detect dependent objects (FIXED UNION ISSUE)

    ----------------------------------------------------------------------

    SELECT string_agg(obj, ', ') INTO v_dependents

    FROM (

        -- Views referencing this table

        SELECT (v.oid::regclass)::text AS obj

        FROM pg_depend d

        JOIN pg_rewrite r ON d.objid=r.oid

        JOIN pg_class v ON r.ev_class=v.oid

        WHERE d.refobjid = v_oid



        UNION



        -- Triggers

        SELECT tg.tgname::text AS obj

        FROM pg_trigger tg

        WHERE tg.tgrelid = v_oid

          AND NOT tg.tgisinternal



        UNION



        -- Functions

        SELECT p.proname::text AS obj

        FROM pg_proc p

        JOIN pg_depend d ON d.objid = p.oid

        WHERE d.refobjid = v_oid

    ) A;



    IF v_dependents IS NOT NULL THEN

        RAISE EXCEPTION 

            '≡ƒÜ½ Cannot delete "%": dependent objects exist: %',

            v_table_name, v_dependents;

    END IF;



    ----------------------------------------------------------------------

    -- 10. Snapshot columns

    ----------------------------------------------------------------------

    SELECT jsonb_agg(row_to_json(r))

    INTO v_snapshot_cols

    FROM (

        SELECT column_name, data_type, is_nullable

        FROM information_schema.columns

        WHERE table_schema='public'

          AND table_name = v_table_name

    ) r;



    ----------------------------------------------------------------------

    -- 11. Drop triggers

    ----------------------------------------------------------------------

    FOR v_sql IN

        SELECT format('DROP TRIGGER IF EXISTS %I ON public.%I;', tg.tgname, v_table_name)

        FROM pg_trigger tg

        WHERE tg.tgrelid = v_oid 

          AND NOT tg.tgisinternal

    LOOP

        EXECUTE v_sql;

    END LOOP;



    ----------------------------------------------------------------------

    -- 12. Drop sequences

    ----------------------------------------------------------------------

    FOR v_sql IN

        SELECT format('DROP SEQUENCE IF EXISTS public.%I;', seq.relname)

        FROM pg_class seq

        JOIN pg_depend d ON d.objid=seq.oid

        WHERE seq.relkind='S'

          AND d.refobjid=v_oid

    LOOP

        EXECUTE v_sql;

    END LOOP;



    ----------------------------------------------------------------------

    -- 13. Drop table

    ----------------------------------------------------------------------

    EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE;', v_table_name);



    ----------------------------------------------------------------------

    -- 14. Clean master_node

    ----------------------------------------------------------------------

    DELETE FROM public.master_node

    WHERE ref_master_table_in_record_id = OLD.in_record_id;



    ----------------------------------------------------------------------

    -- 15. Log event

    ----------------------------------------------------------------------

    INSERT INTO public.security_events (

    attempted_user,

    table_name,

    operation,

    message,

    attempted_data,

    event_time

)

VALUES (

    v_user,

    v_table_name,

    'FORM DELETE',

    format('Deleted dynamic table %s (Rows=%s)', v_table_name, v_row_count),

    jsonb_build_object(

        'form_master_key', OLD.in_record_id,

        'table_api_name', OLD.table_api_name,

        'columns_before_drop', v_snapshot_cols

    ),

    NOW()

);





    RETURN OLD;

END;

$function$