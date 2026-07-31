CREATE OR REPLACE FUNCTION public.ac_requests_direct(p_master_table_id bigint, p_master_key_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE

    v_logs boolean := COALESCE(NULLIF(current_setting('admin.acl_logs', true), ''), 'false')::boolean;

    v_result jsonb := '{}'::jsonb;



    v_perm_count int;

    v_row_count  int;



BEGIN

    ------------------------------------------------------------

    -- SYSTEM CONTEXT

    ------------------------------------------------------------

    PERFORM set_config('row_security','off',true);

    PERFORM set_config('app.system_write','true',true);

    PERFORM set_config('app.system_group_expand','true',true);





    ------------------------------------------------------------

    -- LOG START

    ------------------------------------------------------------

    IF v_logs THEN

        RAISE NOTICE '[ac_requests_direct] START table_id=%, key_id=%',

            p_master_table_id, p_master_key_id;

    END IF;





    ------------------------------------------------------------

    -- BUILD DIRECT REQUEST ACL JSON

    -- Equivalent to original temp table logic

    ------------------------------------------------------------

    WITH allowed_skus AS

    (

        SELECT DISTINCT ref_services_sku_in_record_id

        FROM master_table_access_control_services_sku

        WHERE ref_master_table_in_record_id_to = p_master_table_id

    ),



direct_requests AS (

SELECT DISTINCT perm_val AS perm, r1.ref_requests_in_record_id AS request_id

FROM requests_to_data r1

JOIN master_table_access_control_services_sku m1 ON m1.ref_master_table_in_record_id_to = r1.ref_master_table_in_record_id

CROSS JOIN LATERAL unnest(m1.permission) perm_val

WHERE perm_val IN ('Select','Update','Delete')

AND r1.ref_master_table_in_record_id = p_master_table_id

AND r1.ref_master_key_in_record_id   = p_master_key_id

AND r1.ref_requests_in_record_id IS NOT NULL )



SELECT COALESCE( jsonb_object_agg(perm, request_ids), '{}'::jsonb )

INTO v_result FROM

(SELECT perm, jsonb_agg(request_id ORDER BY request_id) AS request_ids FROM direct_requests GROUP BY perm) final;



    ------------------------------------------------------------

    -- LOG RESULT (structured)

    ------------------------------------------------------------

IF v_logs THEN



    SELECT COUNT(*)

    INTO v_perm_count

    FROM jsonb_object_keys(v_result);



    SELECT COALESCE(SUM(jsonb_array_length(value)), 0)

    INTO v_row_count

    FROM jsonb_each(v_result);



    RAISE NOTICE

        '[ac_requests_direct] RESULT perms=% total_requests=%',

        v_perm_count,

        v_row_count;



END IF;



------------------------------------------------------------

-- RETURN RESULT

------------------------------------------------------------

RETURN v_result;





END;

$function$