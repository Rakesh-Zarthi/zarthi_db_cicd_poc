CREATE OR REPLACE FUNCTION public.ac_update_master_key(p_master_table_id bigint, p_master_key_id bigint, p_users_json jsonb, p_requests_json jsonb, p_uuid_json jsonb)
 RETURNS TABLE(users_changed boolean, requests_changed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    v_logs boolean := COALESCE(NULLIF(current_setting('admin.acl_logs', true), ''), 'false')::boolean;

    v_existing_users    jsonb;

    v_existing_requests jsonb;

    v_existing_uuid     jsonb;

    v_users_changed     boolean := false;

    v_requests_changed  boolean := false;



BEGIN

    ------------------------------------------------------------

    -- SYSTEM CONTEXT

    ------------------------------------------------------------

    PERFORM set_config('row_security','off',true);

    PERFORM set_config('app.system_write','true',true);

    ------------------------------------------------------------

    -- LOCK TARGET ROW

    ------------------------------------------------------------

    SELECT

        in_ref_master_users_id,

        in_ref_master_request_id,

        in_ref_master_user_uuid

    INTO

        v_existing_users,

        v_existing_requests,

        v_existing_uuid

    FROM master_key

    WHERE in_record_id = p_master_key_id

      AND in_ref_master_table = p_master_table_id

    FOR UPDATE;





    ------------------------------------------------------------

    -- CHANGE DETECTION

    ------------------------------------------------------------

    v_users_changed := v_existing_users IS DISTINCT FROM p_users_json;

    v_requests_changed := v_existing_requests IS DISTINCT FROM p_requests_json;

    ------------------------------------------------------------

    -- LOG CHANGE STATE

    ------------------------------------------------------------

    IF v_logs THEN 

        RAISE NOTICE '[ac_persist_master_key] table_id=% key_id=%', 

        p_master_table_id, p_master_key_id;

        RAISE NOTICE '[ac_persist_master_key] users_changed=% existing=% new=%',

        v_users_changed, COALESCE(v_existing_users::text,'NULL'), COALESCE(p_users_json::text,'NULL');

        RAISE NOTICE '[ac_persist_master_key] requests_changed=% existing=% new=%',

        v_requests_changed, COALESCE(v_existing_requests::text,'NULL'), COALESCE(p_requests_json::text,'NULL');

    END IF;





    ------------------------------------------------------------

    -- UPDATE ONLY IF CHANGED

    ------------------------------------------------------------

    IF v_users_changed OR v_requests_changed OR v_existing_uuid IS DISTINCT FROM p_uuid_json

       THEN

       UPDATE master_key

       SET

            in_ref_master_users_id   = p_users_json,

            in_ref_master_request_id = p_requests_json,

            in_ref_master_user_uuid  = p_uuid_json

        WHERE in_record_id = p_master_key_id

        AND in_ref_master_table = p_master_table_id;





        IF v_logs THEN RAISE NOTICE '[ac_persist_master_key] UPDATE APPLIED'; END IF;



    ELSE



        IF v_logs THEN RAISE NOTICE '[ac_persist_master_key] NO UPDATE REQUIRED'; END IF;



    END IF;





    ------------------------------------------------------------

    -- RETURN CHANGE FLAGS

    ------------------------------------------------------------

    RETURN QUERY

    SELECT

        v_users_changed,

        v_requests_changed;





END;

$function$