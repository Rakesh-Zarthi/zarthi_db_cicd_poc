CREATE OR REPLACE FUNCTION public.master_tables_001_import_metadata(p_schema_name text, p_table_name text, p_update_existing boolean DEFAULT false, p_lock boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$

DECLARE

    v_user       text := current_user;



    v_schema     text;

    v_table      text;

    v_table_id   bigint;



    v_created    jsonb := '[]'::jsonb;

    v_master_table_created boolean := false;



    -- counts

    v_inserted_nodes_count bigint := 0;

    v_updated_nodes_count  bigint := 0;



    -- master_key audit actor

    v_actor_uuid UUID := '5c58b64f-e717-4c8c-a971-170acf7a45e7';



    -- metadata ids for "master_table" and "master_node" tables themselves

    v_mt_master_table_id bigint;

    v_mt_master_node_id  bigint;



    rec_ref      record;



    -- helpers for node import

    rec_col                  record;

    v_forward_type           text;

    v_seq_base               integer;

    v_node_label             text;

    v_node_api_name          text;

    v_node_data_type         text;

    v_is_mandatory           boolean;

    v_dropdown_values        text[];

    v_ref_master_table_in_record_id_connected bigint;



BEGIN

    ---------------------------------------------------------------------

    -- 0) Permission check (admin-only)

    ---------------------------------------------------------------------

    IF v_user NOT IN ('postgres', 'admin2', 'admin', 'superuser') THEN

        RAISE EXCEPTION

            'Permission denied. Only admin/superuser can import physical tables into metadata.';

    END IF;



    ---------------------------------------------------------------------

    -- 1) Normalize inputs

    ---------------------------------------------------------------------

    v_schema := lower(COALESCE(NULLIF(trim(p_schema_name), ''), 'public'));

    v_table  := lower(COALESCE(NULLIF(trim(p_table_name), ''), NULL));



    IF v_table IS NULL THEN

        RAISE EXCEPTION 'Table name cannot be NULL or empty.';

    END IF;



    ---------------------------------------------------------------------

    -- 2) Actor UUID (uses session variable first)

    --    Example usage:

    --      SET ADMIN app.CURRENT_USER_ID = '5c58b64f-e717-4c8c-a971-170acf7a45e7';

    ---------------------------------------------------------------------

    PERFORM set_config('app.CURRENT_USER_UUID', v_actor_uuid::text, true);



    ---------------------------------------------------------------------

    -- 3) Prevent dynamic physical table creation trigger side effects

    ---------------------------------------------------------------------

    PERFORM set_config('app.skip_dynamic_table_creation', 'true', true);



    ---------------------------------------------------------------------

    -- 4) Optional locking

    ---------------------------------------------------------------------

    IF p_lock THEN

        LOCK TABLE public.master_table IN EXCLUSIVE MODE;

        LOCK TABLE public.master_node  IN EXCLUSIVE MODE;

        PERFORM pg_advisory_xact_lock(hashtext(v_schema || '.' || v_table));

    END IF;



    ---------------------------------------------------------------------

    -- 5) Validate schema & table existence (partition-safe)

    ---------------------------------------------------------------------

    PERFORM 1 FROM pg_namespace WHERE nspname = v_schema;

    IF NOT FOUND THEN

        RAISE EXCEPTION 'Schema "%" does not exist.', v_schema;

    END IF;



    PERFORM 1

    FROM pg_class c

    JOIN pg_namespace n ON n.oid = c.relnamespace

    WHERE n.nspname = v_schema

      AND c.relname = v_table

      AND c.relkind IN ('r','p'); -- regular/partitioned



    IF NOT FOUND THEN

        RAISE EXCEPTION 'Physical table "%.%" does not exist (or is not a base table).', v_schema, v_table;

    END IF;



    ---------------------------------------------------------------------

    -- 6) Bootstrap lookup: metadata ids for metadata tables

    --    Needed for master_key.in_ref_master_table (NOT NULL)

    ---------------------------------------------------------------------

    SELECT mt.in_record_id

      INTO v_mt_master_table_id

    FROM public.master_table mt

    WHERE mt.table_api_name = 'master_table'

      AND mt."schema" = 'public'

    LIMIT 1;



    SELECT mt.in_record_id

      INTO v_mt_master_node_id

    FROM public.master_table mt

    WHERE mt.table_api_name = 'master_node'

      AND mt."schema" = 'public'

    LIMIT 1;



    IF v_mt_master_table_id IS NULL THEN

        RAISE EXCEPTION 'Missing metadata in master_table for public.master_table. Seed it first.';

    END IF;



    IF v_mt_master_node_id IS NULL THEN

        RAISE EXCEPTION 'Missing metadata in master_table for public.master_node. Seed it first.';

    END IF;



    ---------------------------------------------------------------------

    -- 7) Upsert master_table row (schema-safe)

    ---------------------------------------------------------------------

    SELECT mt.in_record_id

      INTO v_table_id

    FROM public.master_table mt

    WHERE mt.table_api_name = v_table

      AND mt."schema" = v_schema

    LIMIT 1;



    IF v_table_id IS NULL THEN

        INSERT INTO public.master_table(

            table_api_name,

            table_name,

            table_status,

            "schema",



            -- inherited from master_key (NOT NULL fields)

            in_record_name,

            in_ref_master_table,

            in_ref_added_user_uuid,

            in_ref_modified_user_uuid,

            in_added_time,

            in_modified_time

        )

        VALUES (

            v_table,

            initcap(replace(v_table,'_',' ')), 

            'Active',

            v_schema,



            -- MUST be globally unique (master_key unique constraint)

            format('meta.master_table.%s.%s', v_schema, v_table),



            v_mt_master_table_id,

            v_actor_uuid,

            v_actor_uuid,

            clock_timestamp(),

            clock_timestamp()

        )

        RETURNING in_record_id INTO v_table_id;



        v_master_table_created := true;

    ELSE

        -- keep schema updated (safe)

        UPDATE public.master_table

           SET "schema" = v_schema

         WHERE in_record_id = v_table_id;

    END IF;



    ---------------------------------------------------------------------

    -- 8) Prepare temp tables

    ---------------------------------------------------------------------

    DROP TABLE IF EXISTS tmp_columns;

    DROP TABLE IF EXISTS tmp_fk;



    CREATE TEMP TABLE tmp_columns (

        attnum          int,

        column_name     text,

        data_type       text,

        is_nullable     boolean,

        is_identity     boolean,

        is_generated    boolean,

        is_inherited    boolean,

        default_value   text

    ) ON COMMIT DROP;



    CREATE TEMP TABLE tmp_fk (

    column_name     text,

    ref_schema      text,

    ref_table       text,

    ref_table_id    bigint,

    is_unique_fk    boolean

) ON COMMIT DROP;



    ---------------------------------------------------------------------

    -- 9) Load FK relations (schema-safe)

    ---------------------------------------------------------------------

INSERT INTO tmp_fk(column_name, ref_schema, ref_table, ref_table_id, is_unique_fk)

SELECT

    lower(a.attname)  AS column_name,

    lower(rn.nspname) AS ref_schema,

    lower(rc.relname) AS ref_table,

    (

        SELECT mt.in_record_id

        FROM public.master_table mt

        WHERE lower(mt.table_api_name) = lower(rc.relname)

          AND lower(mt."schema") = lower(rn.nspname)

        LIMIT 1

    ) AS ref_table_id,



    -- Detect if FK column is unique

EXISTS (

    SELECT 1

    FROM pg_constraint uc

    WHERE uc.conrelid = ct.oid

      AND uc.contype IN ('u','p')

      AND a.attnum = ANY (uc.conkey)

      AND array_length(uc.conkey,1) = 1

) AND a.attnotnull AS is_unique_fk



FROM pg_constraint c

JOIN pg_class ct        ON ct.oid = c.conrelid

JOIN pg_namespace cn    ON ct.relnamespace = cn.oid

JOIN unnest(c.conkey) WITH ORDINALITY AS keys(attnum, ord) ON true

JOIN pg_attribute a     ON a.attrelid = c.conrelid AND a.attnum = keys.attnum

JOIN pg_class rc        ON rc.oid = c.confrelid

JOIN pg_namespace rn    ON rc.relnamespace = rn.oid

WHERE c.contype = 'f'

  AND lower(cn.nspname) = v_schema

  AND lower(ct.relname) = v_table;



    ---------------------------------------------------------------------

    -- 10) Ensure referenced tables exist in master_table (schema-safe)

    ---------------------------------------------------------------------

    FOR rec_ref IN

        SELECT DISTINCT ref_schema, ref_table

          FROM tmp_fk

         WHERE ref_table_id IS NULL

    LOOP

        IF NOT EXISTS (

            SELECT 1

              FROM public.master_table mt

             WHERE mt.table_api_name = rec_ref.ref_table

               AND mt."schema" = rec_ref.ref_schema

        ) THEN

            INSERT INTO public.master_table(

                table_api_name,

                table_name,

                table_status,

                "schema",



                -- master_key required fields

                in_record_name,

                in_ref_master_table,

                in_ref_added_user_uuid,

                in_ref_modified_user_uuid,

                in_added_time,

                in_modified_time

            )

            VALUES (

                rec_ref.ref_table,

                rec_ref.ref_table,

                'Active',

                rec_ref.ref_schema,



                format('meta.master_table.%s.%s', rec_ref.ref_schema, rec_ref.ref_table),

                v_mt_master_table_id,

                v_actor_uuid,

                v_actor_uuid,

                clock_timestamp(),

                clock_timestamp()

            );

        END IF;

    END LOOP;



UPDATE tmp_fk f

SET ref_table_id = mt.in_record_id

FROM public.master_table mt

WHERE lower(mt.table_api_name) = f.ref_table

  AND lower(mt."schema")       = f.ref_schema

  AND f.ref_table_id IS NULL;



---------------------------------------------------------------------

-- STRICT MODE: Enforce physical FK presence for lookup metadata

---------------------------------------------------------------------

IF p_update_existing THEN



    FOR rec_col IN

        SELECT mn.node_api_name

        FROM public.master_node mn

        WHERE mn.ref_master_table_in_record_id = v_table_id

          AND mn.node_data_type IN ('One-One Lookup','One-Many Lookup')

          AND mn.node_api_name NOT LIKE 'inv_%'

          AND mn.ref_master_table_in_record_id_connected IS NOT NULL

          AND NOT EXISTS (

              SELECT 1

              FROM tmp_fk f

              WHERE f.column_name = mn.node_api_name

          )

    LOOP

        RAISE EXCEPTION

            'Strict mode violation: Metadata lookup exists but physical FK missing for %.% column "%".',

            v_schema,

            v_table,

            rec_col.node_api_name;

    END LOOP;



END IF;





-- Strict cardinality enforcement

IF p_update_existing THEN

FOR rec_col IN

    SELECT mn.node_api_name, mn.node_data_type

    FROM public.master_node mn

    WHERE mn.ref_master_table_in_record_id = v_table_id

      AND mn.node_data_type IN ('One-One Lookup','One-Many Lookup')

      AND mn.node_api_name NOT LIKE 'inv_%'

      AND mn.ref_master_table_in_record_id_connected IS NOT NULL

LOOP



    IF rec_col.node_data_type = 'One-One Lookup'

       AND NOT EXISTS (

           SELECT 1

           FROM tmp_fk f

           WHERE f.column_name = rec_col.node_api_name

             AND f.is_unique_fk = true

       )

    THEN

        RAISE EXCEPTION

            'Strict mode violation: One-One metadata but physical FK is not UNIQUE for %.% column "%".',

            v_schema,

            v_table,

            rec_col.node_api_name;

    END IF;



END LOOP;



END IF;



    ---------------------------------------------------------------------

    -- 11) Load physical columns

    ---------------------------------------------------------------------

    INSERT INTO tmp_columns

    SELECT

        a.attnum,

        lower(a.attname) AS column_name,

        t.typname AS data_type,

        (NOT a.attnotnull)                AS is_nullable,

        (a.attidentity <> '')             AS is_identity,

        (a.attgenerated <> '')            AS is_generated,

        (a.attinhcount > 0)               AS is_inherited,

        pg_get_expr(ad.adbin, ad.adrelid) AS default_value

    FROM pg_attribute a

    JOIN pg_class c      ON a.attrelid = c.oid

    JOIN pg_namespace n  ON c.relnamespace = n.oid

    JOIN pg_type t       ON a.atttypid = t.oid

    LEFT JOIN pg_attrdef ad

           ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum

    WHERE c.relkind IN ('r','p')

      AND a.attnum > 0

      AND NOT a.attisdropped

      AND n.nspname = v_schema

      AND c.relname = v_table

    ORDER BY a.attnum;



    ---------------------------------------------------------------------

    -- 12) Optional sync mode: update existing nodes (drift fix)

    --     IMPORTANT: update master_key audit modified columns too

    ---------------------------------------------------------------------

    IF p_update_existing THEN

        UPDATE public.master_node mn

           SET

               is_nullable   = c.is_nullable,

               is_identity   = c.is_identity,

               is_generated  = c.is_generated,

               is_inherited  = c.is_inherited,

               default_value = c.default_value,

               is_mandatory  = NOT c.is_nullable,

               ref_master_table_in_record_id_connected = fk.ref_table_id,



               -- inherited audit

               in_ref_modified_user_uuid = v_actor_uuid,

               in_modified_time = clock_timestamp()

          FROM tmp_columns c

          LEFT JOIN (

              SELECT f.column_name, MIN(f.ref_table_id) AS ref_table_id

              FROM tmp_fk f

              GROUP BY f.column_name

          ) fk ON fk.column_name = c.column_name

         WHERE mn.ref_master_table_in_record_id = v_table_id

           AND mn.node_api_name = c.column_name

           AND (

                 mn.is_nullable   IS DISTINCT FROM c.is_nullable

              OR mn.is_identity   IS DISTINCT FROM c.is_identity

              OR mn.is_generated  IS DISTINCT FROM c.is_generated

              OR mn.is_inherited  IS DISTINCT FROM c.is_inherited

              OR mn.default_value IS DISTINCT FROM c.default_value

              OR mn.is_mandatory  IS DISTINCT FROM (NOT c.is_nullable)

              OR mn.ref_master_table_in_record_id_connected IS DISTINCT FROM fk.ref_table_id

           );



        GET DIAGNOSTICS v_updated_nodes_count = ROW_COUNT;

    END IF;



    ---------------------------------------------------------------------

    -- 13) Insert missing nodes

    ---------------------------------------------------------------------

    SELECT COALESCE(MAX(node_sequence_number), 0)

      INTO v_seq_base

      FROM public.master_node

     WHERE ref_master_table_in_record_id = v_table_id;



    FOR rec_col IN

        SELECT c.*,

               (SELECT MIN(f.ref_table_id)

                  FROM tmp_fk f

                 WHERE f.column_name = c.column_name) AS ref_table_id

        FROM tmp_columns c

        WHERE NOT EXISTS (

            SELECT 1

              FROM public.master_node mn

             WHERE mn.ref_master_table_in_record_id = v_table_id

               AND mn.node_api_name = c.column_name

        )

        ORDER BY c.attnum

    LOOP

        v_seq_base := v_seq_base + 1;



        v_node_label     := initcap(replace(rec_col.column_name,'_',' '));

        v_node_api_name  := rec_col.column_name;

        v_ref_master_table_in_record_id_connected := rec_col.ref_table_id;

        v_is_mandatory   := NOT rec_col.is_nullable;



        v_node_data_type :=

                CASE

                WHEN v_ref_master_table_in_record_id_connected IS NOT NULL THEN

                CASE WHEN EXISTS (

                SELECT 1

                FROM tmp_fk f

                WHERE f.column_name = rec_col.column_name

                AND f.is_unique_fk = true

                ) THEN 'One-One Lookup' ELSE 'One-Many Lookup' END



                -- Master Key Column				

                WHEN rec_col.column_name = 'in_record_id'                       THEN 'Record ID'

                WHEN rec_col.column_name = 'in_record_name'                     THEN 'Record Name'

                

                WHEN rec_col.column_name = 'in_added_time'                      THEN 'Custom Date'

                WHEN rec_col.column_name = 'in_modified_time'                   THEN 'Custom Date'

                

        --      WHEN rec_col.column_name = 'in_ref_master_table'                THEN 'Record ID'

                

                -- true UUID audit fields

                WHEN rec_col.column_name = 'in_ref_added_user_uuid'             THEN 'UUID'

                WHEN rec_col.column_name = 'in_ref_modified_user_uuid'          THEN 'UUID'

                

                -- external numeric reference

                WHEN rec_col.column_name = 'zoho_id'                            THEN 'Record ID'

                

                -- ACL / permission JSON blobs (NOT ids)

                WHEN rec_col.column_name = 'in_ref_master_user_uuid'            THEN 'Config JSON'

                WHEN rec_col.column_name = 'in_ref_master_users_role_id'        THEN 'Config JSON'

                WHEN rec_col.column_name = 'in_ref_master_request_id'           THEN 'Config JSON'

                WHEN rec_col.column_name = 'in_ref_master_users_id'             THEN 'Config JSON'





				

                WHEN rec_col.data_type = 'int8'                                 THEN 'BIGINT'

                WHEN rec_col.data_type = 'single_line_text'                     THEN 'Single Line Text'

                WHEN rec_col.data_type = 'multiline_text'                       THEN 'Multiline Text'

                WHEN rec_col.data_type = 'multiline_html'                       THEN 'Multiline HTML'

                WHEN rec_col.data_type = 'multiline_html_text'                  THEN 'Multiline HTML Rich Text'

                WHEN rec_col.data_type = 'email_address'                        THEN 'Email Address'

                WHEN rec_col.data_type = 'url_address'                          THEN 'URL Address'

                WHEN rec_col.data_type = 'phone_number'                         THEN 'Phone Number'

                WHEN rec_col.data_type = 'postal_code'                          THEN 'Postal Code'

                WHEN rec_col.data_type = 'city'                                 THEN 'City'

                WHEN rec_col.data_type = 'state'                                THEN 'State'

                WHEN rec_col.data_type = 'country'                              THEN 'Country'

                WHEN rec_col.data_type = 'address'                              THEN 'Address'

                WHEN rec_col.data_type = 'attachment'                           THEN 'Attachment'

                WHEN rec_col.data_type = 'record_name'                          THEN 'Record Name'

                WHEN rec_col.data_type = 'record_id'                            THEN 'Record ID'

                WHEN rec_col.data_type = 'uuid'                                 THEN 'UUID'

                WHEN rec_col.data_type = 'dropdown'                             THEN 'Single-Select Dropdown'

                WHEN rec_col.data_type = '_dropdown'                            THEN 'Multi-Select Dropdown'

                WHEN rec_col.data_type = 'data_type_dropdown'                   THEN 'DataType Dropdown'

                WHEN rec_col.data_type = 'table_or_node_api_name'               THEN 'Table/Node API Name'

                WHEN rec_col.data_type = 'auto_number'                          THEN 'Auto Number'

                WHEN rec_col.data_type = 'decimal1'                             THEN 'Decimal Number'

                WHEN rec_col.data_type = 'percentage'                           THEN 'Percentage'    

                WHEN rec_col.data_type = 'config_json'                          THEN 'Config JSON'

                WHEN rec_col.data_type = 'levels'                               THEN 'Levels'

                WHEN rec_col.data_type = 'checkbox'                             THEN 'Checkbox'

                WHEN rec_col.data_type = 'timefield'                            THEN 'Timefield'

                WHEN rec_col.data_type = 'datetime'                             THEN 'Datetime'

                WHEN rec_col.data_type = 'custom_date'                          THEN 'Custom Date'

                WHEN rec_col.data_type = 'custom_number'                        THEN 'Custom Number'

                WHEN rec_col.data_type = 'date_time'                            THEN 'Composite Datetime'

                WHEN rec_col.data_type = 'permission_level'                     THEN 'Permission Level'



      

                ELSE NULL

            END;



                IF v_node_data_type IS NULL THEN

            RAISE EXCEPTION

                'Unsupported physical data type "%" for column "%.%"',

                rec_col.data_type,

                v_table,

                rec_col.column_name;

            END IF;



        v_dropdown_values := NULL;



        IF rec_col.data_type IN ('dropdown','_dropdown','data_type_dropdown') THEN

            BEGIN

                IF rec_col.data_type IN ('dropdown','data_type_dropdown') THEN

                    EXECUTE format(

                        $$SELECT ARRAY(

                               SELECT DISTINCT trim(%1$I::text)

                               FROM %2$I.%3$I

                               WHERE %1$I IS NOT NULL AND %1$I::text <> ''

                               ORDER BY 1

                               LIMIT 200

                           )$$,

                        rec_col.column_name, v_schema, v_table

                    )

                    INTO v_dropdown_values;

                ELSE

                    EXECUTE format(

                        $$SELECT ARRAY(

                               SELECT DISTINCT trim(x::text)

                               FROM %2$I.%3$I t

                               CROSS JOIN LATERAL unnest(t.%1$I) x

                               WHERE t.%1$I IS NOT NULL

                               ORDER BY 1

                               LIMIT 200

                           )$$,

                        rec_col.column_name, v_schema, v_table

                    )

                    INTO v_dropdown_values;

                END IF;

            EXCEPTION WHEN OTHERS THEN

                v_dropdown_values := ARRAY['Option 1','Option 2'];

            END;



            IF v_dropdown_values IS NULL OR array_length(v_dropdown_values,1) IS NULL THEN

                v_dropdown_values := ARRAY['Option 1','Option 2'];

            END IF;

        END IF;



        INSERT INTO public.master_node(

            node_label,

            node_api_name,

            node_data_type,

            is_mandatory,

            is_master_key,

            dropdown_values,

            node_sequence_number,

            ref_master_table_in_record_id,

            ref_master_table_in_record_id_connected,

            is_nullable,

            is_identity,

            is_generated,

            is_inherited,

            default_value,



            -- master_key required fields

            in_record_name,

            in_ref_master_table,

            in_ref_added_user_uuid,

            in_ref_modified_user_uuid,

            in_added_time,

            in_modified_time

        )

        VALUES (

            v_node_label,

            v_node_api_name,

            v_node_data_type,

            v_is_mandatory,

            FALSE,

            v_dropdown_values,

            v_seq_base,

            v_table_id,

            v_ref_master_table_in_record_id_connected,

            rec_col.is_nullable,

            rec_col.is_identity,

            rec_col.is_generated,

            rec_col.is_inherited,

            rec_col.default_value,



            -- globally unique master_key name

            format('meta.master_node.%s.%s.%s', v_schema, v_table, v_node_api_name),



            v_mt_master_node_id,

            v_actor_uuid,

            v_actor_uuid,

            clock_timestamp(),

            clock_timestamp()

        );



        v_inserted_nodes_count := v_inserted_nodes_count + 1;



        v_created := v_created || jsonb_build_object(

            'column',                 v_node_api_name,

            'data_type',              v_node_data_type,

            'ref_master_table_in_record_id_connected', v_ref_master_table_in_record_id_connected,

            'dropdown_values',        v_dropdown_values

        );

    END LOOP;



    ---------------------------------------------------------------------

    -- 14) Reverse virtual nodes (per referenced table)

    --     Note: must also set master_key fields

    ---------------------------------------------------------------------

FOR rec_col IN

    SELECT mn.in_record_id AS forward_id,

           mn.node_api_name AS forward_api,

           mn.ref_master_table_in_record_id_connected AS target_table_id,

           mn.node_data_type AS forward_type

    FROM public.master_node mn

    WHERE mn.ref_master_table_in_record_id = v_table_id

      AND mn.ref_master_table_in_record_id_connected IS NOT NULL

      AND mn.node_data_type IN ('One-Many Lookup','One-One Lookup')

      AND mn.node_api_name NOT LIKE 'inv_%'

LOOP



    ------------------------------------------------------------------

    -- cache forward lookup type

    ------------------------------------------------------------------

    v_node_data_type :=

        CASE

        WHEN rec_col.forward_type = 'One-One Lookup'

        THEN 'One-One Lookup'

        ELSE 'Many-One Lookup'

        END;



    ------------------------------------------------------------------

    -- Deterministic inverse API name

    ------------------------------------------------------------------

    v_node_api_name := 'inv_' || v_table || '_' || rec_col.forward_api;



    ------------------------------------------------------------------

    -- Label derived from API name

    ------------------------------------------------------------------

    v_node_label := initcap(replace(v_node_api_name, '_', ' '));



------------------------------------------------------------------

-- Ensure reverse node exists (insert if missing)

------------------------------------------------------------------

IF NOT EXISTS (

    SELECT 1

    FROM public.master_node

    WHERE ref_master_table_in_record_id = rec_col.target_table_id

      AND node_api_name = v_node_api_name

) THEN



    SELECT COALESCE(MAX(node_sequence_number),0)+1

      INTO v_seq_base

    FROM public.master_node

    WHERE ref_master_table_in_record_id = rec_col.target_table_id;



    INSERT INTO public.master_node(

        node_label,

        node_api_name,

        node_data_type,

        node_sequence_number,

        ref_master_table_in_record_id,

        ref_master_table_in_record_id_connected,

        ref_master_node_inverse_in_record_id,

        is_mandatory,

        is_master_key,

        in_record_name,

        in_ref_master_table,

        in_ref_added_user_uuid,

        in_ref_modified_user_uuid,

        in_added_time,

        in_modified_time

    )

    VALUES (

        v_node_label,

        v_node_api_name,

        v_node_data_type,

        v_seq_base,

        rec_col.target_table_id,

        v_table_id,

        rec_col.forward_id,

        FALSE,

        FALSE,

        format('meta.master_node.reverse.%s.%s.%s',

               v_schema, v_table, rec_col.forward_api),

        v_mt_master_node_id,

        v_actor_uuid,

        v_actor_uuid,

        clock_timestamp(),

        clock_timestamp()

    );

END IF;



------------------------------------------------------------------

-- Enforce reverse correctness (drift correction)

------------------------------------------------------------------

UPDATE public.master_node r

SET

    node_data_type = v_node_data_type,

    ref_master_table_in_record_id_connected = v_table_id,

    ref_master_node_inverse_in_record_id = rec_col.forward_id

WHERE r.ref_master_table_in_record_id = rec_col.target_table_id

  AND r.node_api_name = v_node_api_name;



    ------------------------------------------------------------------

    -- Ensure forward node is linked to reverse node

    ------------------------------------------------------------------

UPDATE public.master_node f

SET ref_master_node_inverse_in_record_id = r.in_record_id

FROM public.master_node r

WHERE f.in_record_id = rec_col.forward_id

  AND r.ref_master_table_in_record_id = rec_col.target_table_id

  AND r.node_api_name = v_node_api_name

  AND f.ref_master_node_inverse_in_record_id IS DISTINCT FROM r.in_record_id;



END LOOP;





    ---------------------------------------------------------------------

    -- 15) Cleanup

    ---------------------------------------------------------------------

    DROP TABLE IF EXISTS tmp_columns;

    DROP TABLE IF EXISTS tmp_fk;



    ---------------------------------------------------------------------

    -- 16) Return result

    ---------------------------------------------------------------------

    RETURN jsonb_build_object(

        'schema',                v_schema,

        'table_api_name',        v_table,

        'master_table_id',       v_table_id,

        'master_table_created',  v_master_table_created,

        'inserted_nodes_count',  v_inserted_nodes_count,

        'updated_nodes_count',   v_updated_nodes_count,

        'created_nodes',         v_created,

        'status',                'Import complete'

    );



EXCEPTION WHEN OTHERS THEN

    DROP TABLE IF EXISTS tmp_columns;

    DROP TABLE IF EXISTS tmp_fk;



    RAISE EXCEPTION

        'import_physical_table_to_metadata("%","%") failed: %',

        COALESCE(v_schema, p_schema_name),

        COALESCE(v_table, p_table_name),

        SQLERRM;

END;

$function$