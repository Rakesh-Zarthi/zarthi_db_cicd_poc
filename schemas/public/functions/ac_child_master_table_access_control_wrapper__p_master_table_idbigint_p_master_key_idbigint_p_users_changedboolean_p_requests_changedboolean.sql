CREATE OR REPLACE FUNCTION public.ac_child_master_table_access_control_wrapper(p_master_table_id bigint, p_master_key_id bigint, p_users_changed boolean, p_requests_changed boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



BEGIN



    ------------------------------------------------------------

    -- SYSTEM CONTEXT

    ------------------------------------------------------------

    PERFORM set_config('row_security','off',true);

    PERFORM set_config('app.system_write','true',true);

    PERFORM set_config('app.system_group_expand','true',true);



    ------------------------------------------------------------

    -- USERS TOP-DOWN PROPAGATION

    ------------------------------------------------------------

    PERFORM public.ac_users_top_down(

        p_master_table_id,

        p_master_key_id,

        p_users_changed

    );





    ------------------------------------------------------------

    -- REQUESTS TOP-DOWN PROPAGATION

    ------------------------------------------------------------

    PERFORM public.ac_requests_top_down(

        p_master_table_id,

        p_master_key_id,

        p_requests_changed

    );





END;

$function$