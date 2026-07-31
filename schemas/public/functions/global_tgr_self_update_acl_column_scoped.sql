CREATE OR REPLACE FUNCTION public.global_tgr_self_update_acl_column_scoped()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE

    v_users_json   jsonb;

    v_uuid_json    jsonb;

    v_request_json jsonb;



BEGIN



    ------------------------------------------------------------

    -- BUILD ACL JSON FROM WRAPPER

    ------------------------------------------------------------

    SELECT

        users_id_json,

        users_uuid_json,

        request_id_json

    INTO

        v_users_json,

        v_uuid_json,

        v_request_json

    FROM public.ac_self_update_master_table_access_control_wrapper(NEW)

    LIMIT 1;





    ------------------------------------------------------------

    -- APPLY VALUES TO NEW ROW

    ------------------------------------------------------------

    NEW.in_ref_master_users_id :=

        COALESCE(v_users_json, '{}'::jsonb);



    NEW.in_ref_master_user_uuid :=

        COALESCE(v_uuid_json, '{}'::jsonb);



    NEW.in_ref_master_request_id :=

        COALESCE(v_request_json, '{}'::jsonb);





    ------------------------------------------------------------

    -- RETURN UPDATED ROW

    ------------------------------------------------------------

    RETURN NEW;



END;

$function$