CREATE OR REPLACE FUNCTION public.ac_update_in_ref_master_users_id(_ref_master_table_in_record_id bigint, _ref_master_key_in_record_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

DECLARE

    r               record;

    v_sql           text;

    v_user_json     jsonb := '{}'::jsonb;

    v_existing_json jsonb;

BEGIN

    --------------------------------------------------

    -- SYSTEM CONTEXT (RLS SAFE)

    --------------------------------------------------

    PERFORM set_config('row_security','off',true);

    PERFORM set_config('app.system_write','true',true);



    --------------------------------------------------

    -- SESSION-SAFE RECURSION GUARD

    --------------------------------------------------

    PERFORM public.ac_temp_table_guard();



    IF EXISTS (

        SELECT 1

        FROM temp_acl_visited

        WHERE table_id  = _ref_master_table_in_record_id

          AND record_id = _ref_master_key_in_record_id

    ) THEN

        RETURN;

    END IF;



    INSERT INTO temp_acl_visited(table_id, record_id)

    VALUES (_ref_master_table_in_record_id, _ref_master_key_in_record_id);



    --------------------------------------------------

    -- TEMP PERMISSION ACCUMULATOR

    --------------------------------------------------

    CREATE TEMP TABLE IF NOT EXISTS temp_table_users_permissions (

        perm     text CHECK (perm IN ('Select','Update','Delete')),

        users_id bigint,

        PRIMARY KEY (perm, users_id)

    ) ON COMMIT DROP;



    TRUNCATE temp_table_users_permissions;



    --------------------------------------------------

    -- STEP 1 ΓÇö ROOT ACL (UNCHANGED)

    --------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM master_table_access_control_users m

        WHERE m.ref_master_table_in_record_id_to = _ref_master_table_in_record_id

          AND m.is_root = true

    ) THEN

        INSERT INTO temp_table_users_permissions

        SELECT p.perm, u.in_record_id

        FROM users u

        JOIN master_table_access_control_users m

          ON m.ref_master_table_in_record_id_to = u.in_ref_master_table

         AND m.is_root = true

        CROSS JOIN LATERAL unnest(m.permission) p(perm)

        WHERE u.in_record_id = _ref_master_key_in_record_id

        ON CONFLICT DO NOTHING;

    END IF;



    --------------------------------------------------

    -- STEP 2 ΓÇö BOTTOM ΓåÆ TOP (IMMEDIATE PARENT ONLY)

    --------------------------------------------------

    FOR r IN

    (

        -- SINGLE-SELECT

        SELECT

            mt_child.table_api_name  AS child_table,

            n1.node_api_name         AS parent_fk,

            mt_parent.table_api_name AS parent_table,

            m.permission

        FROM master_table_access_control_users m

        JOIN master_node n1 ON n1.in_record_id = m.ref_master_node_in_record_id_from

        JOIN master_table mt_child ON mt_child.in_record_id = m.ref_master_table_in_record_id_to

        JOIN master_node n2 ON n2.in_record_id = n1.ref_master_node_inverse_in_record_id

        JOIN master_table mt_parent ON mt_parent.in_record_id = n2.ref_master_table_in_record_id

        WHERE n1.node_data_type = 'Single-Select Lookup'

          AND mt_child.in_record_id = _ref_master_table_in_record_id



        UNION ALL



        -- MULTI-SELECT

        SELECT

            mt_child.table_api_name,

            n3.node_api_name,

            mt_parent.table_api_name,

            m.permission

        FROM master_table_access_control_users m

        JOIN master_node n1 ON n1.in_record_id = m.ref_master_node_in_record_id_from

        JOIN master_table mt_child ON mt_child.in_record_id = m.ref_master_table_in_record_id_to

        JOIN master_node n2 ON n2.in_record_id = n1.in_record_id

        JOIN master_node n3 ON n3.in_record_id = n2.ref_master_node_inverse_in_record_id

        JOIN master_table mt_parent ON mt_parent.in_record_id = n2.ref_master_table_in_record_id

        WHERE n1.node_data_type = 'Multi-Select Lookup'

          AND mt_child.in_record_id = _ref_master_table_in_record_id

    )

LOOP



    -- ===============================

    -- 2A ΓÇö PRINCIPAL EDGE (SEED)

    -- parent = users

    -- ===============================

    IF r.parent_table = 'users' THEN

        v_sql := '

        INSERT INTO temp_table_users_permissions (perm, users_id)

        SELECT p.perm, parent.in_record_id

        FROM '||quote_ident(r.child_table)||' c

        JOIN users parent

          ON c.'||quote_ident(r.parent_fk)||' = parent.in_record_id

        CROSS JOIN LATERAL unnest($2::text[]) p(perm)

        WHERE c.in_record_id = $1

          AND p.perm IN (''Select'',''Update'',''Delete'')

        ON CONFLICT DO NOTHING';



        EXECUTE v_sql

        USING _ref_master_key_in_record_id, r.permission;



    -- ===============================

    -- 2B ΓÇö CONTAINMENT EDGE (INHERIT)

    -- parent Γëá users

    -- ===============================

    ELSE

        v_sql := '

        INSERT INTO temp_table_users_permissions (perm, users_id)

        SELECT j.key, usr::bigint

        FROM '||quote_ident(r.child_table)||' c

        JOIN '||quote_ident(r.parent_table)||' parent

          ON c.'||quote_ident(r.parent_fk)||' = parent.in_record_id

        CROSS JOIN LATERAL jsonb_each(

            COALESCE(parent.in_ref_master_users_id, ''{}''::jsonb)

        ) j

        CROSS JOIN LATERAL jsonb_array_elements_text(j.value) usr

        WHERE c.in_record_id = $1

          AND j.key = ANY($2::text[])

        ON CONFLICT DO NOTHING';



        EXECUTE v_sql

        USING _ref_master_key_in_record_id, r.permission;

    END IF;



END LOOP;



    --------------------------------------------------

    -- STEP 3 ΓÇö BUILD JSON

    --------------------------------------------------

    SELECT COALESCE(

        jsonb_object_agg(perm, ids ORDER BY perm),

        '{}'::jsonb

    )

    INTO v_user_json

    FROM (

        SELECT perm, jsonb_agg(users_id ORDER BY users_id) ids

        FROM temp_table_users_permissions

        GROUP BY perm

    ) s;



    --------------------------------------------------

    -- STEP 4 ΓÇö PERSIST

    --------------------------------------------------

    SELECT in_ref_master_users_id

      INTO v_existing_json

      FROM master_key

     WHERE in_record_id = _ref_master_key_in_record_id

       AND in_ref_master_table = _ref_master_table_in_record_id

     FOR UPDATE;



    IF v_existing_json IS DISTINCT FROM v_user_json THEN

        UPDATE master_key

           SET in_ref_master_users_id = v_user_json

         WHERE in_record_id = _ref_master_key_in_record_id

           AND in_ref_master_table = _ref_master_table_in_record_id;

    END IF;



    --------------------------------------------------

    -- STEP 5 ΓÇö TOP ΓåÆ BOTTOM (RECURSIVE, GUARDED)

    --------------------------------------------------

     FOR r IN

    (

        /* SINGLE-SELECT */

        SELECT

            mt_parent.in_record_id  AS parent_table_id,

            mt_child.in_record_id   AS child_table_id,

            mt_child.table_api_name AS child_table,

            n1.node_api_name        AS child_fk

        FROM master_table_access_control_users m

        JOIN master_node n1 ON n1.in_record_id = m.ref_master_node_in_record_id_from

        JOIN master_table mt_child ON mt_child.in_record_id = m.ref_master_table_in_record_id_to

        JOIN master_node n2 ON n2.in_record_id = n1.ref_master_node_inverse_in_record_id

        JOIN master_table mt_parent ON mt_parent.in_record_id = n2.ref_master_table_in_record_id

        WHERE n1.node_data_type = 'Single-Select Lookup'



        UNION ALL



        /* MULTI-SELECT */

        SELECT

            mt_parent.in_record_id,

            mt_child.in_record_id,

            mt_child.table_api_name,

            n3.node_api_name

        FROM master_table_access_control_users m

        JOIN master_node n1 ON n1.in_record_id = m.ref_master_node_in_record_id_from

        JOIN master_table mt_child ON mt_child.in_record_id = m.ref_master_table_in_record_id_to

        JOIN master_node n2 ON n2.in_record_id = n1.in_record_id

        JOIN master_node n3 ON n3.in_record_id = n2.ref_master_node_inverse_in_record_id

        JOIN master_table mt_parent ON mt_parent.in_record_id = n2.ref_master_table_in_record_id

        WHERE n1.node_data_type = 'Multi-Select Lookup'

    )

    LOOP

        IF r.parent_table_id <> _ref_master_table_in_record_id THEN

            CONTINUE;

        END IF;



        EXECUTE

        'SELECT public.ac_update_in_ref_master_users_id($1, c.in_record_id)

         FROM '||quote_ident(r.child_table)||' c

         WHERE c.'||quote_ident(r.child_fk)||' = $2'

        USING r.child_table_id, _ref_master_key_in_record_id;

    END LOOP;



END;

$function$