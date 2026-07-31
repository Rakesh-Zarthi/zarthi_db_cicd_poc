CREATE OR REPLACE FUNCTION public.automation_create_table_node()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_user              text := current_user;



    -- table / metadata

    v_table_name          text;   -- owner table API name (physical table)

    v_connected_table     text;   -- table referenced by ref_master_table_in_record_id_connected

    v_user_api_name       text;   -- normalized node_api_name

    v_node_data_type_raw  text;   -- UI label

    v_node_data_type      text;   -- mapped domain type



    -- DDL helpers

    v_sql                 text;

    v_exists              boolean := false;

    v_not_null_clause     text := '';

    v_default_clause      text := '';

    v_seq_name            text := NULL;

    v_fk_name             text;

    v_delete_action       text;



    -- multi-select lookup helpers

    v_new_col             text;

    v_singular_base       text;



    -- flags

    v_is_master_key       boolean;

    v_is_mandatory        boolean;

    v_is_multi_lookup     boolean := false;

    v_is_single_lookup    boolean := false;

BEGIN

    ----------------------------------------------------------------------

    -- 1. Permission check (admin-only)

    ----------------------------------------------------------------------

    IF v_user NOT IN ('postgres', 'admin', 'superuser') THEN

        RAISE EXCEPTION

            'Permission denied. Only admin/superuser can create dynamic nodes.';

    END IF;



    ----------------------------------------------------------------------

    -- 2. Recursion guard for auto-generated reverse nodes

    ----------------------------------------------------------------------

    IF NEW.node_api_name LIKE '__auto_reverse__%' THEN

        RAISE NOTICE 'Skipping recursion for auto-generated node: %', NEW.node_api_name;

        RETURN NEW;

    END IF;



    ----------------------------------------------------------------------

    -- 3. Resolve owner table name from master_table

    ----------------------------------------------------------------------

    SELECT mt.table_api_name

      INTO v_table_name

      FROM public.master_table mt

     WHERE mt.in_record_id = NEW.ref_master_table_in_record_id::bigint

     LIMIT 1;



    IF v_table_name IS NULL THEN

        RAISE EXCEPTION 'No table found for ref_master_table_in_record_id %',

            NEW.ref_master_table_in_record_id;

    END IF;



    ----------------------------------------------------------------------

    -- 4. Resolve connected table (if any)

    ----------------------------------------------------------------------

    IF NEW.ref_master_table_in_record_id_connected IS NOT NULL THEN

        SELECT mt.table_api_name

          INTO v_connected_table

          FROM public.master_table mt

         WHERE mt.in_record_id = NEW.ref_master_table_in_record_id_connected::bigint

         LIMIT 1;



        IF v_connected_table IS NULL THEN

            RAISE EXCEPTION 'ref_master_table_in_record_id_connected % does not exist',

                NEW.ref_master_table_in_record_id_connected;

        END IF;

    END IF;



    ----------------------------------------------------------------------

    -- 5. Normalize and validate node_api_name

    ----------------------------------------------------------------------

    IF NEW.node_api_name IS NULL OR trim(NEW.node_api_name) = '' THEN

        RAISE EXCEPTION 'node_api_name is required';

    END IF;



    v_user_api_name := lower(trim(NEW.node_api_name));



    IF v_user_api_name ~ '\s' THEN

        RAISE EXCEPTION 'node_api_name "%" contains whitespace', v_user_api_name;

    END IF;



    ----------------------------------------------------------------------

    -- 5b. Attachments ΓåÆ metadata only, no physical column

    ----------------------------------------------------------------------

    IF v_user_api_name ILIKE '%attachment%' THEN

        RAISE NOTICE 'Skipping physical column creation for attachment field: %', v_user_api_name;

        RETURN NEW;

    END IF;



    ----------------------------------------------------------------------

    -- 6. Validate node_data_type and map to domain

    ----------------------------------------------------------------------

    IF NEW.node_data_type IS NULL THEN

        RAISE EXCEPTION 'node_data_type is required';

    END IF;



    v_node_data_type_raw := lower(trim(NEW.node_data_type));



    v_is_multi_lookup  := (v_node_data_type_raw = 'multi-select lookup');

    v_is_single_lookup := (v_node_data_type_raw = 'single-select lookup');



    CASE v_node_data_type_raw

        WHEN 'Single-Select Lookup'    THEN v_node_data_type := 'public."record_id"';

        WHEN 'Multi-Select Lookup'     THEN v_node_data_type := 'public."record_id"'; -- used for reverse FKs

        WHEN 'Single Line Text'        THEN v_node_data_type := 'public."single_line_text"';

        WHEN 'Multiline Text'          THEN v_node_data_type := 'public."multiline_text"';

        WHEN 'Multiline HTML'          THEN v_node_data_type := 'public."multiline_html"';

        WHEN 'Custom Number'           THEN v_node_data_type := 'public."custom_number"';

        WHEN 'Single-Select Dropdown'  THEN v_node_data_type := 'public."dropdown"';

        WHEN 'Multi-Select Dropdown'   THEN v_node_data_type := 'public."_dropdown"';

        WHEN 'Checkbox'                THEN v_node_data_type := 'public."checkbox"';

        WHEN 'Custom Date'             THEN v_node_data_type := 'public."custom_date"';

        WHEN 'Email Address'           THEN v_node_data_type := 'public."email_address"';

        WHEN 'Phone Number'            THEN v_node_data_type := 'public."phone_number"';

        WHEN 'URL Address'             THEN v_node_data_type := 'public."url_address"';

        WHEN 'Postal Code'             THEN v_node_data_type := 'public."postal_code"';

        WHEN 'Data Type Dropdown'      THEN v_node_data_type := 'public."data_type_dropdown"';

        WHEN 'Percentage'              THEN v_node_data_type := 'public."percentage"';

        WHEN 'Auto Number'             THEN v_node_data_type := 'public."auto_number"';

        WHEN 'Timefield'               THEN v_node_data_type := 'public."timefield"';

        ELSE

            RAISE EXCEPTION 'Unsupported data type "%"', v_node_data_type_raw;

    END CASE;



    ----------------------------------------------------------------------

    -- 7. Reserved column names protection

    ----------------------------------------------------------------------

    IF v_user_api_name IN (

        'in_record_id','in_record_name','in_added_time','in_modified_time',

        'in_ref_added_user','in_ref_modified_user','in_ref_master_table'

    ) THEN

        RAISE EXCEPTION 'Column name "%" is reserved.', v_user_api_name;

    END IF;



    ----------------------------------------------------------------------

    -- 8. Flags (master key / mandatory)

    ----------------------------------------------------------------------

    v_is_master_key := COALESCE(NEW.is_master_key, false);

    v_is_mandatory  := COALESCE(NEW.is_mandatory,  false);



    IF v_is_master_key THEN

        NEW.is_mandatory := TRUE;

        v_is_mandatory   := TRUE;



        v_not_null_clause := 'NOT NULL';



        v_seq_name := format('%I_%I_seq', v_table_name, v_user_api_name);

        EXECUTE format('CREATE SEQUENCE IF NOT EXISTS public.%I START 1;', v_seq_name);



        v_default_clause := format(

            'DEFAULT (format(''%s-%%05s'', nextval(''public.%I'')))',

            COALESCE(NEW.pre_text_master_key, upper(left(v_user_api_name, 3))),

            v_seq_name

        );

    ELSIF v_is_mandatory THEN

        v_not_null_clause := 'NOT NULL';

    END IF;



    ----------------------------------------------------------------------

    -- 9. MULTI-SELECT LOOKUP: create reverse FK column in connected table

    ----------------------------------------------------------------------

    IF v_is_multi_lookup THEN

        IF v_connected_table IS NULL THEN

            RAISE EXCEPTION 'multi-select lookup requires ref_master_table_in_record_id_connected';

        END IF;



        -- singularize base name

        v_singular_base := regexp_replace(v_user_api_name, '_list$','');

        IF v_singular_base ~ 'ies$' THEN

            v_singular_base := regexp_replace(v_singular_base, 'ies$','y');

        ELSIF v_singular_base ~ 'ses$' THEN

            v_singular_base := regexp_replace(v_singular_base, 'es$','');

        ELSIF v_singular_base ~ 's$' THEN

            v_singular_base := regexp_replace(v_singular_base, 's$','');

        END IF;



        v_new_col := v_singular_base || '_id';



        -- does column already exist?

        SELECT EXISTS (

            SELECT 1

              FROM information_schema.columns

             WHERE table_schema = 'public'

               AND table_name   = v_connected_table

               AND column_name  = v_new_col

        )

        INTO v_exists;



        IF NOT v_exists THEN

            -- 9.1 add column to connected table

            EXECUTE format(

                'LOCK TABLE public.%I IN ACCESS EXCLUSIVE MODE;',

                v_connected_table

            );



            EXECUTE format(

                'ALTER TABLE public.%I

                   ADD COLUMN %I public."record_id" %s;',

                v_connected_table,

                v_new_col,

                CASE WHEN v_is_mandatory THEN 'NOT NULL' ELSE '' END

            );



            -- 9.2 FK to owner table

            v_fk_name := format('fk_%s_%s', v_connected_table, v_new_col);

            v_delete_action := CASE WHEN v_is_mandatory THEN 'CASCADE' ELSE 'SET NULL' END;



            EXECUTE format(

                'ALTER TABLE public.%I

                   ADD CONSTRAINT %I

                   FOREIGN KEY (%I)

                   REFERENCES public.%I(in_record_id)

                   ON UPDATE CASCADE ON DELETE %s;',

                v_connected_table, v_fk_name, v_new_col, v_table_name, v_delete_action

            );



            EXECUTE format(

                'CREATE INDEX IF NOT EXISTS idx_%I_%I_fk

                   ON public.%I (%I);',

                v_connected_table, v_new_col, v_connected_table, v_new_col

            );



            -- 9.3 auto-reverse metadata on connected table

            INSERT INTO public.master_node (

                node_label,

                node_api_name,

                node_data_type,

                ref_master_table_in_record_id,

                node_sequence_number,

                is_mandatory,

                is_master_key,

                ref_master_table_in_record_id_connected

            )

            SELECT

                initcap(v_new_col),

                format('__auto_reverse__%s', v_new_col),

                'single-select lookup',

                NEW.ref_master_table_in_record_id_connected::bigint,

                COALESCE(

                    (SELECT MAX(node_sequence_number) + 1

                       FROM public.master_node

                      WHERE ref_master_table_in_record_id = NEW.ref_master_table_in_record_id_connected::bigint),

                    1

                ),

                FALSE,

                FALSE,

                NEW.ref_master_table_in_record_id::bigint;

        END IF;



        -- 9.4 log reverse FK creation

        INSERT INTO public.security_events (

            attempted_user,

            table_name,

            operation,

            message,

            attempted_data,

            event_time

        ) VALUES (

            v_user,

            v_connected_table,

            'ALTER TABLE ADD REVERSE FK',

            format(

                'Added reverse FK column %I (multi-select lookup from %I) on %I',

                v_new_col, v_table_name, v_connected_table

            ),

            jsonb_build_object(

                'node_master_key', NEW.in_record_id,

                'node_api_name',   v_user_api_name,

                'reverse_column',  v_new_col,

                'owner_table',     v_table_name

            ),

            NOW()

        );



        RETURN NEW; -- no physical column on owner table

    END IF;



    ----------------------------------------------------------------------

    -- 10. All other types (including single-select lookup): column on owner

    ----------------------------------------------------------------------

    -- if column already exists, just return (metadata only)

    SELECT EXISTS (

        SELECT 1

          FROM information_schema.columns

         WHERE table_schema = 'public'

           AND table_name   = v_table_name

           AND column_name  = v_user_api_name

    )

    INTO v_exists;



    IF NOT v_exists THEN

        EXECUTE format(

            'LOCK TABLE public.%I IN ACCESS EXCLUSIVE MODE;',

            v_table_name

        );



        v_sql := format(

            'ALTER TABLE public.%I

               ADD COLUMN %I %s %s %s;',

            v_table_name,

            v_user_api_name,

            v_node_data_type,

            v_default_clause,

            v_not_null_clause

        );

        EXECUTE v_sql;

    END IF;



    ----------------------------------------------------------------------

    -- 11. FK for single-select lookup

    ----------------------------------------------------------------------

    IF v_is_single_lookup THEN

        IF v_connected_table IS NULL THEN

            RAISE EXCEPTION 'single-select lookup requires ref_master_table_in_record_id_connected';

        END IF;



        v_fk_name := format('fk_%s_%s', v_table_name, v_user_api_name);

        v_delete_action := CASE WHEN v_is_mandatory THEN 'CASCADE' ELSE 'SET NULL' END;



        -- add FK only if not present

        PERFORM 1

        FROM pg_constraint c

        JOIN pg_class t       ON t.oid = c.conrelid

        JOIN pg_namespace n   ON n.oid = t.relnamespace

        WHERE n.nspname = 'public'

          AND t.relname = v_table_name

          AND c.conname = v_fk_name;



        IF NOT FOUND THEN

            EXECUTE format(

                'ALTER TABLE public.%I

                   ADD CONSTRAINT %I

                   FOREIGN KEY (%I)

                   REFERENCES public.%I(in_record_id)

                   ON UPDATE CASCADE ON DELETE %s;',

                v_table_name, v_fk_name, v_user_api_name, v_connected_table, v_delete_action

            );



            EXECUTE format(

                'CREATE INDEX IF NOT EXISTS idx_%I_%I_fk

                   ON public.%I (%I);',

                v_table_name, v_user_api_name, v_table_name, v_user_api_name

            );

        END IF;



        ------------------------------------------------------------------

        -- Auto reverse metadata: list of owner rows on connected table

        ------------------------------------------------------------------

        INSERT INTO public.master_node (

            node_label,

            node_api_name,

            node_data_type,

            ref_master_table_in_record_id,

            node_sequence_number,

            is_mandatory,

            is_master_key,

            ref_master_table_in_record_id_connected

        )

        SELECT

            format('%s List', initcap(v_table_name)),

            format('__auto_reverse__%s_list', lower(v_table_name)),

            'multi-select lookup',

            NEW.ref_master_table_in_record_id_connected::bigint,

            COALESCE(

                (SELECT MAX(node_sequence_number) + 1

                   FROM public.master_node

                  WHERE ref_master_table_in_record_id = NEW.ref_master_table_in_record_id_connected::bigint),

                1

            ),

            FALSE,

            FALSE,

            NEW.ref_master_table_in_record_id::bigint

        WHERE NOT EXISTS (

            SELECT 1

              FROM public.master_node

             WHERE ref_master_table_in_record_id = NEW.ref_master_table_in_record_id_connected::bigint

               AND node_api_name = format('__auto_reverse__%s_list', lower(v_table_name))

        );

    END IF;



    ----------------------------------------------------------------------

    -- 12. DROPDOWN TYPES: attach fn_validate_all_dropdowns() trigger

    ----------------------------------------------------------------------

    IF v_node_data_type_raw IN ('single-select dropdown', 'multi-select dropdown') THEN

        -- Check if trigger already exists on the owner table

        PERFORM 1

        FROM pg_trigger tg

        JOIN pg_class tbl   ON tbl.oid = tg.tgrelid

        JOIN pg_namespace n ON n.oid   = tbl.relnamespace

        WHERE n.nspname = 'public'

          AND tbl.relname = v_table_name

          AND tg.tgname = 'tgr_validate_all_dropdowns';



        IF NOT FOUND THEN

            EXECUTE format(

                'CREATE TRIGGER tgr_validate_all_dropdowns

                    BEFORE INSERT OR UPDATE ON public.%I

                    FOR EACH ROW

                    EXECUTE FUNCTION fn_validate_all_dropdowns();',

                v_table_name

            );



            RAISE NOTICE 'Attached fn_validate_all_dropdowns trigger to table: %', v_table_name;

        END IF;

    END IF;



    ----------------------------------------------------------------------

    -- 13. Audit log for owner table change

    ----------------------------------------------------------------------

    INSERT INTO public.security_events (

        attempted_user,

        table_name,

        operation,

        message,

        attempted_data,

        event_time

    ) VALUES (

        v_user,

        v_table_name,

        'ALTER TABLE ADD COLUMN',

        format('Added column %I (%s) to %I', v_user_api_name, v_node_data_type, v_table_name),

        jsonb_build_object(

            'node_master_key', NEW.in_record_id,

            'node_api_name',   v_user_api_name,

            'data_type',       v_node_data_type_raw

        ),

        NOW()

    );



    RETURN NEW;

END;

$function$