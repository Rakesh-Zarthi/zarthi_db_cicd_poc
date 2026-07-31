CREATE OR REPLACE FUNCTION public.ac_self_update_master_access_parent(p_master_table_id bigint, p_master_key_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_parent_id bigint;

BEGIN



    -- Example for requests (you can generalize later)

    SELECT ref_requests_in_record_id_immediate_parent

    INTO v_parent_id

    FROM requests

    WHERE in_record_id = p_master_key_id;



    IF v_parent_id IS NULL THEN

        RETURN;

    END IF;



    -- call wrapper on parent ONLY ONCE

    PERFORM public.ac_self_child_update_master_access_wrapper(

        p_master_table_id,

        v_parent_id

    );



END;

$function$