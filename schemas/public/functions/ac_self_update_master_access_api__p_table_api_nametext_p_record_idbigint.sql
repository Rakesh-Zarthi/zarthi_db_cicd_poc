CREATE OR REPLACE FUNCTION public.ac_self_update_master_access_api(p_table_api_name text, p_record_id bigint)
 RETURNS TABLE(users_changed boolean, requests_changed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    v_table_id bigint;



    v_users_direct_json     jsonb := '{}'::jsonb;

    v_users_inherit_json    jsonb := '{}'::jsonb;

    v_users_json            jsonb := '{}'::jsonb;



    v_requests_direct_json  jsonb := '{}'::jsonb;

    v_requests_inherit_json jsonb := '{}'::jsonb;

    v_requests_json         jsonb := '{}'::jsonb;



    v_uuid_json             jsonb := '{}'::jsonb;



    v_users_changed         boolean := false;

    v_requests_changed      boolean := false;



BEGIN



    ------------------------------------------------------------

    -- RESOLVE TABLE ID

    ------------------------------------------------------------

    SELECT mt.in_record_id

    INTO v_table_id

    FROM public.master_table mt

    WHERE mt.table_api_name = p_table_api_name;



    IF v_table_id IS NULL THEN

        RAISE EXCEPTION

        'Invalid table_api_name: %',

        p_table_api_name;

    END IF;



    ------------------------------------------------------------

    -- SAFETY

    ------------------------------------------------------------

    IF p_record_id IS NULL THEN

        RETURN QUERY

        SELECT false, false;



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

    v_users_direct_json :=

        public.ac_users_direct(

            v_table_id,

            p_record_id

        );



    v_users_inherit_json :=

        public.ac_users_bottom_up(

            v_table_id,

            p_record_id,

            NULL::record

        );



    v_users_json :=

        public.ac_merge_direct_bottom_up_json(

            COALESCE(v_users_direct_json,'{}'::jsonb),

            COALESCE(v_users_inherit_json,'{}'::jsonb)

        );



    ------------------------------------------------------------

    -- REQUESTS ACL

    ------------------------------------------------------------

    v_requests_direct_json :=

        public.ac_requests_direct(

            v_table_id,

            p_record_id

        );



    v_requests_inherit_json :=

        public.ac_requests_bottom_up(

            v_table_id,

            p_record_id,

            NULL::record

        );



    v_requests_json :=

        public.ac_merge_direct_bottom_up_json(

            COALESCE(v_requests_direct_json,'{}'::jsonb),

            COALESCE(v_requests_inherit_json,'{}'::jsonb)

        );



    ------------------------------------------------------------

    -- UUID BUILD

    ------------------------------------------------------------

    v_uuid_json :=

        public.ac_build_uuid(

            COALESCE(v_users_json,'{}'::jsonb),

            COALESCE(v_requests_json,'{}'::jsonb)

        );



    ------------------------------------------------------------

    -- PERSIST

    ------------------------------------------------------------

    SELECT

        t.users_changed,

        t.requests_changed

    INTO

        v_users_changed,

        v_requests_changed

    FROM public.ac_update_master_key(

        v_table_id,

        p_record_id,

        v_users_json,

        v_requests_json,

        v_uuid_json

    ) t;



    ------------------------------------------------------------

    -- RETURN

    ------------------------------------------------------------

    RETURN QUERY

    SELECT

        COALESCE(v_users_changed,false),

        COALESCE(v_requests_changed,false);



END;

$function$