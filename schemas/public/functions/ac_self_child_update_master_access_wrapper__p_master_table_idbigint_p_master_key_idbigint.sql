CREATE OR REPLACE FUNCTION public.ac_self_child_update_master_access_wrapper(p_master_table_id bigint, p_master_key_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE

    v_users_direct_json     jsonb := '{}'::jsonb;

    v_users_inherit_json    jsonb := '{}'::jsonb;

    v_users_json            jsonb := '{}'::jsonb;



    v_requests_direct_json  jsonb := '{}'::jsonb;

    v_requests_inherit_json jsonb := '{}'::jsonb;

    v_requests_json         jsonb := '{}'::jsonb;



    v_uuid_json             jsonb := '{}'::jsonb;



    v_users_changed    boolean := false;

    v_requests_changed boolean := false;



BEGIN



    ------------------------------------------------------------

    -- SAFETY

    ------------------------------------------------------------

    IF p_master_table_id IS NULL OR p_master_key_id IS NULL THEN

        RETURN;

    END IF;



    ------------------------------------------------------------

    -- SYSTEM CONTEXT

    ------------------------------------------------------------

    PERFORM set_config('row_security','off',true);

    PERFORM set_config('app.system_write','true',true);



    ------------------------------------------------------------

    -- USERS ACL

    ------------------------------------------------------------

    v_users_direct_json :=

        public.ac_users_direct(p_master_table_id, p_master_key_id);



    v_users_inherit_json :=

        public.ac_users_bottom_up(

            p_master_table_id,

            p_master_key_id,

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

        public.ac_requests_direct(p_master_table_id, p_master_key_id);



    v_requests_inherit_json :=

        public.ac_requests_bottom_up(

            p_master_table_id,

            p_master_key_id,

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

    SELECT COALESCE(users_changed,false),

           COALESCE(requests_changed,false)

    INTO v_users_changed,

         v_requests_changed

    FROM public.ac_update_master_key(

        p_master_table_id,

        p_master_key_id,

        v_users_json,

        v_requests_json,

        v_uuid_json

    );



    ------------------------------------------------------------

    -- PROPAGATE ONLY IF CHANGED

    ------------------------------------------------------------

    IF v_users_changed THEN

        PERFORM public.ac_users_top_down(

            p_master_table_id,

            p_master_key_id,

            true

        );

    END IF;



    IF v_requests_changed THEN

        PERFORM public.ac_requests_top_down(

            p_master_table_id,

            p_master_key_id,

            true

        );

    END IF;



END;

$function$