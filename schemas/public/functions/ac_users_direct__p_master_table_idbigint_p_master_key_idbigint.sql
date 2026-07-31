CREATE OR REPLACE FUNCTION public.ac_users_direct(p_master_table_id bigint, p_master_key_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    v_result jsonb := '{}'::jsonb;



    v_logs boolean := COALESCE(NULLIF(current_setting('admin.acl_logs', true), ''), 'false')::boolean;



BEGIN



    ------------------------------------------------------------

    -- LOG START

    ------------------------------------------------------------

    IF v_logs THEN

        RAISE NOTICE '[ac_users_direct] START table_id=%, key_id=%',

            p_master_table_id, p_master_key_id;

    END IF;





    ------------------------------------------------------------

    -- CHECK ROOT ACCESS EXISTS

    ------------------------------------------------------------

    IF EXISTS

    (

        SELECT 1

        FROM master_table_access_control_users m

        WHERE m.ref_master_table_in_record_id_to = p_master_table_id

        AND m.is_root = true

    )

    THEN



        ------------------------------------------------------------

        -- BUILD JSON DIRECTLY

        ------------------------------------------------------------

        SELECT COALESCE(

            jsonb_object_agg(perm, ids ORDER BY perm),

            '{}'::jsonb

        )

        INTO v_result

        FROM

        (

            SELECT

                perm,

                jsonb_agg(DISTINCT u.in_record_id ORDER BY u.in_record_id) ids

            FROM users u

            JOIN master_table_access_control_users m

                ON m.ref_master_table_in_record_id_to = u.in_ref_master_table

                AND m.is_root = true

                AND m.ref_master_table_in_record_id_to = p_master_table_id

            CROSS JOIN LATERAL unnest(m.permission) perm

            WHERE u.in_record_id = p_master_key_id

            AND perm IN ('Select','Update','Delete')

            GROUP BY perm

        ) s;



    END IF;





    ------------------------------------------------------------

    -- LOG RESULT

    ------------------------------------------------------------

    IF v_logs THEN

        RAISE NOTICE '[ac_users_direct] RESULT=%', v_result;

    END IF;





    ------------------------------------------------------------

    -- RETURN

    ------------------------------------------------------------

    RETURN v_result;





END;

$function$