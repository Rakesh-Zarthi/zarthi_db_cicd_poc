CREATE OR REPLACE FUNCTION public.ac_build_uuid(p_users_json jsonb, p_requests_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    v_logs boolean := COALESCE(NULLIF(current_setting('admin.acl_logs', true), ''), 'false')::boolean;

    v_result jsonb := '{}'::jsonb;



BEGIN



    ------------------------------------------------------------

    -- SYSTEM CONTEXT

    ------------------------------------------------------------

    PERFORM set_config('row_security','off',true);

    PERFORM set_config('app.system_group_expand','true',true);





    ------------------------------------------------------------

    -- LOG INPUT

    ------------------------------------------------------------

    IF v_logs THEN

        RAISE NOTICE

        '[ac_build_uuid] START users_json=% requests_json=%',

        COALESCE(p_users_json::text,'NULL'),

        COALESCE(p_requests_json::text,'NULL');

    END IF;

    ------------------------------------------------------------

    -- BUILD UUID JSON

    ------------------------------------------------------------

    SELECT

        COALESCE( jsonb_object_agg(perm, uuid_list), '{}'::jsonb )

    INTO v_result

    FROM ( SELECT perm, jsonb_agg(DISTINCT user_id ORDER BY user_id) AS uuid_list FROM (

            ----------------------------------------------------

            -- USERS ΓåÆ UUID {} REQUEST OWNER ΓåÆ UUID

            ----------------------------------------------------

            SELECT 

            key AS perm, 

            u.user_id AS user_id

            FROM jsonb_each(COALESCE(p_users_json,'{}'))

            CROSS JOIN LATERAL jsonb_array_elements_text(value) uid

            JOIN users u ON u.in_record_id = uid::bigint

            UNION ALL

            SELECT 

            key AS perm, 

            u.user_id AS user_id

            FROM jsonb_each(COALESCE(p_requests_json,'{}'))

            CROSS JOIN LATERAL jsonb_array_elements_text(value) req_id

            JOIN requests r ON r.in_record_id = req_id::bigint

            JOIN users u ON u.in_record_id = r.owner ) combined

            GROUP BY perm ) final;



    ------------------------------------------------------------

    -- LOG RESULT

    ------------------------------------------------------------

    IF v_logs THEN RAISE NOTICE '[ac_build_uuid] RESULT=%', v_result; END IF;





    ------------------------------------------------------------

    -- RETURN

    ------------------------------------------------------------

    RETURN v_result;





END;

$function$