CREATE OR REPLACE FUNCTION public.ac_update_in_ref_master_users_role_id(_ref_master_table_in_record_id bigint, _ref_master_key_in_record_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

DECLARE

    r record;

    v_sql text;



    v_role_json jsonb := '{}'::jsonb;

    v_existing_json jsonb;



    v_table_name text;

    v_root_node_api_name text;

BEGIN





    -------------------------------------------------------------------------

    -- Function to Store - users_onboarding_id in in_ref_master_users_role_id

    -------------------------------------------------------------------------

    ------------------------------------------------------------------

    -- system context

    ------------------------------------------------------------------

    PERFORM set_config('row_security','off',true);

    PERFORM set_config('app.system_write','true',true);

    PERFORM set_config('app.system_group_expand','true',true);



    ------------------------------------------------------------------

    -- safety: record must belong to table

    ------------------------------------------------------------------

    IF NOT EXISTS (

        SELECT 1

        FROM master_key

        WHERE in_record_id = _ref_master_key_in_record_id

          AND in_ref_master_table = _ref_master_table_in_record_id

    ) THEN

        RAISE EXCEPTION

            'Record % does not belong to master_table %',

            _ref_master_key_in_record_id,

            _ref_master_table_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- resolve physical table name

    ------------------------------------------------------------------

    SELECT table_api_name

      INTO v_table_name

      FROM master_table

     WHERE in_record_id = _ref_master_table_in_record_id;



    IF v_table_name IS NULL THEN

        RAISE EXCEPTION 'No table_api_name for master_table %',

            _ref_master_table_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- resolve ROOT node

    ------------------------------------------------------------------

    SELECT n.node_api_name

      INTO v_root_node_api_name

      FROM master_table_access_control_users_roles m

      JOIN master_node n

        ON n.in_record_id = m.ref_master_node_in_record_id_from

     WHERE m.ref_master_table_in_record_id_to = _ref_master_table_in_record_id

       AND m.is_root = true

     LIMIT 1;



    ------------------------------------------------------------------

    -- temp table

    ------------------------------------------------------------------

    DROP TABLE IF EXISTS temp_table_users_roles_permissions;



    CREATE TEMP TABLE temp_table_users_roles_permissions (

        perm text NOT NULL,

        users_roles_onboarding_id bigint NOT NULL,

        PRIMARY KEY (perm, users_roles_onboarding_id)

    ) ON COMMIT DROP;



    ------------------------------------------------------------------

    -- STEP 1 ΓÇö ROOT grants

    ------------------------------------------------------------------

    IF v_root_node_api_name IS NOT NULL THEN

        v_sql := format($f$

            INSERT INTO temp_table_users_roles_permissions (perm, users_roles_onboarding_id)

            SELECT p.perm, uo.in_record_id

            FROM users_roles_onboarding uo

            JOIN master_table_access_control_users_roles m1

              ON m1.ref_users_roles_in_record_id = uo.ref_users_roles_in_record_id

             AND m1.is_root = true

            JOIN %I src

              ON src.%I = uo.ref_users_in_record_id

            CROSS JOIN LATERAL unnest(m1.permission) p(perm)

            WHERE src.in_record_id = $1

              AND m1.ref_master_table_in_record_id_to = $2

              AND p.perm IN ('Select','Update','Delete')

            ON CONFLICT DO NOTHING

        $f$, v_table_name, v_root_node_api_name);



        EXECUTE v_sql

        USING _ref_master_key_in_record_id,

              _ref_master_table_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- STEP 2 ΓÇö Bottom ΓåÆ Top

    ------------------------------------------------------------------

    FOR r IN

        SELECT *

        FROM (

            SELECT

                m1.ref_users_roles_in_record_id AS role_id,

                m1.ref_master_table_in_record_id_to AS master_table_from,

                m2.table_api_name AS table_from,

                n1.node_api_name,

                m3.in_record_id AS master_table_to,

                m3.table_api_name AS table_to,

                m1.permission

            FROM master_table_access_control_users_roles m1

            JOIN master_node n1 ON n1.in_record_id = m1.ref_master_node_in_record_id_from

            JOIN master_table m2 ON m2.in_record_id = m1.ref_master_table_in_record_id_to

            JOIN master_node n2 ON n2.in_record_id = n1.ref_master_node_inverse_in_record_id

            JOIN master_table m3 ON m3.in_record_id = n2.ref_master_table_in_record_id

            WHERE n1.node_data_type = 'Single-Select Lookup'



            UNION ALL



            SELECT

                m1.ref_users_roles_in_record_id,

                m1.ref_master_table_in_record_id_to,

                m2.table_api_name,

                n3.node_api_name,

                m3.in_record_id,

                m3.table_api_name,

                m1.permission

            FROM master_table_access_control_users_roles m1

            JOIN master_node n1 ON n1.in_record_id = m1.ref_master_node_in_record_id_from

            JOIN master_table m2 ON m2.in_record_id = m1.ref_master_table_in_record_id_to

            JOIN master_node n2 ON n2.in_record_id = n1.in_record_id

            JOIN master_node n3 ON n3.in_record_id = n2.ref_master_node_inverse_in_record_id

            JOIN master_table m3 ON m3.in_record_id = n2.ref_master_table_in_record_id

            WHERE n1.node_data_type = 'Multi-Select Lookup'

        ) e

        WHERE e.master_table_from = _ref_master_table_in_record_id

    LOOP

        v_sql := format($f$

            INSERT INTO temp_table_users_roles_permissions (perm, users_roles_onboarding_id)

            SELECT p.perm, uo.in_record_id

            FROM %I src

            JOIN %I tgt

              ON src.%I = tgt.in_record_id

            CROSS JOIN LATERAL unnest($2::text[]) p(perm)

            JOIN jsonb_array_elements_text(

                COALESCE(tgt.in_ref_master_users_role_id -> p.perm, '[]'::jsonb)

            ) x(onboarding_id) ON TRUE

            JOIN users_roles_onboarding uo

              ON uo.in_record_id = x.onboarding_id::bigint

             AND uo.ref_users_roles_in_record_id = $1

            WHERE src.in_record_id = $3

              AND p.perm IN ('Select','Update','Delete')

            ON CONFLICT DO NOTHING

        $f$, r.table_from, r.table_to, r.node_api_name);



        EXECUTE v_sql

        USING r.role_id,

              r.permission,

              _ref_master_key_in_record_id;

    END LOOP;



    ------------------------------------------------------------------

    -- STEP 3 ΓÇö persist JSON safely

    ------------------------------------------------------------------

    SELECT COALESCE(

        jsonb_object_agg(perm, ids ORDER BY perm),

        '{}'::jsonb

    )

    INTO v_role_json

    FROM (

        SELECT perm,

               jsonb_agg(users_roles_onboarding_id ORDER BY users_roles_onboarding_id) AS ids

        FROM temp_table_users_roles_permissions

        GROUP BY perm

    ) s;



    SELECT in_ref_master_users_role_id

      INTO v_existing_json

      FROM master_key

     WHERE in_record_id = _ref_master_key_in_record_id

       AND in_ref_master_table = _ref_master_table_in_record_id;



    IF v_existing_json IS DISTINCT FROM v_role_json THEN

        UPDATE master_key

           SET in_ref_master_users_role_id = v_role_json

         WHERE in_record_id = _ref_master_key_in_record_id

           AND in_ref_master_table = _ref_master_table_in_record_id;

    END IF;



    ------------------------------------------------------------------

    -- STEP 4 ΓÇö recursive propagation

    ------------------------------------------------------------------

    FOR r IN

        SELECT *

        FROM (

            SELECT

                m3.in_record_id AS master_table_from,

                m3.table_api_name AS table_from,

                n1.node_api_name,

                m2.in_record_id AS master_table_to,

                m2.table_api_name AS table_to

            FROM master_table_access_control_users_roles m1

            JOIN master_node n1 ON n1.in_record_id = m1.ref_master_node_in_record_id_from

            JOIN master_table m2 ON m2.in_record_id = m1.ref_master_table_in_record_id_to

            JOIN master_node n2 ON n2.in_record_id = n1.ref_master_node_inverse_in_record_id

            JOIN master_table m3 ON m3.in_record_id = n2.ref_master_table_in_record_id

            WHERE n1.node_data_type = 'Single-Select Lookup'



            UNION ALL



            SELECT

                m3.in_record_id,

                m3.table_api_name,

                n3.node_api_name,

                m2.in_record_id,

                m2.table_api_name

            FROM master_table_access_control_users_roles m1

            JOIN master_node n1 ON n1.in_record_id = m1.ref_master_node_in_record_id_from

            JOIN master_table m2 ON m2.in_record_id = m1.ref_master_table_in_record_id_to

            JOIN master_node n2 ON n2.in_record_id = n1.in_record_id

            JOIN master_node n3 ON n3.in_record_id = n2.ref_master_node_inverse_in_record_id

            JOIN master_table m3 ON m3.in_record_id = n2.ref_master_table_in_record_id

            WHERE n1.node_data_type = 'Multi-Select Lookup'

        ) e

        WHERE e.master_table_from = _ref_master_table_in_record_id

    LOOP

        v_sql := format($f$

            SELECT public.ac_update_in_ref_master_users_role_id($1, tgt.in_record_id)

            FROM %I src

            JOIN %I tgt

              ON tgt.%I = src.in_record_id

            WHERE src.in_record_id = $2

        $f$, r.table_from, r.table_to, r.node_api_name);



        EXECUTE v_sql

        USING r.master_table_to,

              _ref_master_key_in_record_id;

    END LOOP;



END;

$function$