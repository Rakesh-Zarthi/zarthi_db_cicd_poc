CREATE OR REPLACE FUNCTION public.ac_self_update_master_table_access_control_wrapper(p_row record)
 RETURNS TABLE(users_id_json jsonb, users_uuid_json jsonb, request_id_json jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE

    v_row_json jsonb;



    v_table_id bigint;

    v_key_id   bigint;



    v_users_direct     jsonb := '{}'::jsonb;

    v_users_inherit    jsonb := '{}'::jsonb;

    v_users_json       jsonb := '{}'::jsonb;



    v_requests_direct  jsonb := '{}'::jsonb;

    v_requests_inherit jsonb := '{}'::jsonb;

    v_requests_json    jsonb := '{}'::jsonb;



    v_uuid_json        jsonb := '{}'::jsonb;



BEGIN



    ------------------------------------------------------------

    -- DEBUG

    ------------------------------------------------------------

    RAISE NOTICE 'WRAPPER row = %', p_row;



    ------------------------------------------------------------

    -- SAFETY CHECK

    ------------------------------------------------------------

    IF p_row IS NULL THEN

        RETURN QUERY SELECT '{}'::jsonb,'{}'::jsonb,'{}'::jsonb;

        RETURN;

    END IF;



    ------------------------------------------------------------

    -- SAFE RECORD ACCESS

    ------------------------------------------------------------

    v_row_json := to_jsonb(p_row);



    v_table_id := (v_row_json->>'in_ref_master_table')::bigint;

    v_key_id   := (v_row_json->>'in_record_id')::bigint;



    RAISE NOTICE 'WRAPPER table_id=% key_id=%', v_table_id, v_key_id;



    IF v_table_id IS NULL OR v_key_id IS NULL THEN

        RETURN QUERY SELECT '{}'::jsonb,'{}'::jsonb,'{}'::jsonb;

        RETURN;

    END IF;



    ------------------------------------------------------------

    -- SYSTEM CONTEXT

    ------------------------------------------------------------

    PERFORM set_config('row_security','off',true);

    PERFORM set_config('app.system_write','true',true);

    PERFORM set_config('app.system_group_expand','true',true);



    ------------------------------------------------------------

    -- USERS ACL

    ------------------------------------------------------------

    v_users_direct :=

        public.ac_users_direct(v_table_id, v_key_id);



    -- Force row-mode inheritance

    v_users_inherit :=

        public.ac_users_bottom_up(

            NULL,

            NULL,

            p_row

        );



    v_users_json :=

        public.ac_merge_direct_bottom_up_json(

            v_users_direct,

            v_users_inherit

        );



    ------------------------------------------------------------

    -- REQUEST ACL

    ------------------------------------------------------------

    v_requests_direct :=

        public.ac_requests_direct(v_table_id, v_key_id);



    v_requests_inherit :=

        public.ac_requests_bottom_up(

            NULL,

            NULL,

            p_row

        );



    v_requests_json :=

        public.ac_merge_direct_bottom_up_json(

            v_requests_direct,

            v_requests_inherit

        );



    ------------------------------------------------------------

    -- UUID ACL

    ------------------------------------------------------------

    v_uuid_json :=

        public.ac_build_uuid(

            v_users_json,

            v_requests_json

        );



    ------------------------------------------------------------

    -- RETURN

    ------------------------------------------------------------

    RETURN QUERY

    SELECT

        COALESCE(v_users_json,'{}'::jsonb),

        COALESCE(v_uuid_json,'{}'::jsonb),

        COALESCE(v_requests_json,'{}'::jsonb);



END;

$function$