CREATE OR REPLACE FUNCTION public.ac_requests_top_down(p_master_table_id bigint, p_master_key_id bigint, p_requests_changed boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    v_logs boolean := COALESCE(NULLIF(current_setting('admin.acl_logs', true), ''), 'false')::boolean;

    r record;

    v_sql text;



BEGIN



    ------------------------------------------------------------

    -- EXIT EARLY IF NO CHANGE

    ------------------------------------------------------------

    IF NOT p_requests_changed THEN

    IF v_logs THEN RAISE NOTICE '[ac_requests_top_down] SKIPPED (no change)';

    END IF; 

    RETURN; 

    END IF;





    ------------------------------------------------------------

    -- LOG START

    ------------------------------------------------------------

    IF v_logs THEN

        RAISE NOTICE

        '[ac_requests_top_down] START table_id=% key_id=%',

        p_master_table_id,

        p_master_key_id;

    END IF;





    ------------------------------------------------------------

    -- FIND CHILD EDGES

    ------------------------------------------------------------

FOR r IN

(

    SELECT *

    FROM (



        --------------------------------------------------

        -- SINGLE-SELECT LOOKUP

        --------------------------------------------------

        SELECT

            table_from.in_record_id               AS table_from_id,

            table_from.table_api_name             AS table_from_api_name,

            n1.node_api_name                      AS fk,

            table_to.in_record_id                 AS table_to_id,

            table_to.table_api_name               AS table_to_api_name,

            m.permission,

            'One-Many Lookup' as node_data_type

        FROM master_table_access_control_services_sku m

        JOIN master_node n1 ON m.ref_master_node_in_record_id_from = n1.in_record_id

        JOIN master_table table_from ON table_from.in_record_id = n1.ref_master_table_in_record_id

        JOIN master_table table_to ON m.ref_master_table_in_record_id_to = table_to.in_record_id

        WHERE n1.node_data_type = 'One-Many Lookup'

        AND table_from.in_record_id = p_master_table_id



        UNION ALL



          --------------------------------------------------

          -- MULTI-SELECT LOOKUP

          --------------------------------------------------

        SELECT

            table_from.in_record_id       AS table_from_id,

            table_from.table_api_name     AS table_from_api_name,

            n2.node_api_name              AS fk,

            table_to.in_record_id         AS table_to_id,

            table_to.table_api_name       AS table_to_api_name,

            m.permission,

            'Many-One Lookup' as node_data_type

        FROM master_table_access_control_services_sku m

        JOIN master_node n1 ON n1.in_record_id = m.ref_master_node_in_record_id_from

        JOIN master_node n2 ON n1.ref_master_node_inverse_in_record_id = n2.in_record_id

        JOIN master_table table_from ON n1.ref_master_table_in_record_id =  table_from.in_record_id

        JOIN master_table table_to ON m.ref_master_table_in_record_id_to = table_to.in_record_id

        WHERE n1.node_data_type = 'Many-One Lookup'

        AND   table_from.in_record_id = p_master_table_id



    ) edges

)

LOOP



        ------------------------------------------------------------

        -- LOG EDGE

        ------------------------------------------------------------

        IF v_logs THEN



            RAISE NOTICE '========================================';



            RAISE NOTICE

            '[ac_requests_top_down] PROPAGATION from=% to=% type=%',

            r.table_from_api_name,

            r.table_to_api_name,

            r.node_data_type;



        END IF;



-- BUILD RECURSION SQL (correct child propagation)



-- SINGLE SELECT FUNCTION EXECUTION



IF r.node_data_type = 'One-Many Lookup' THEN



v_sql := format(

    'SELECT public.ac_self_child_update_master_access_wrapper(%s, c.%I)

     FROM %I c

     WHERE c.in_record_id = $1

     AND c.%I IS NOT NULL',

     r.table_to_id,               

     r.fk,                        

     r.table_from_api_name,     

     r.fk

);



-- MULTI SELECT FUNCTION EXECUTION



ELSIF r.node_data_type = 'Many-One Lookup' THEN



v_sql := format(

    'SELECT public.ac_self_child_update_master_access_wrapper(%s, c.in_record_id)

     FROM %I c

     WHERE c.%I = $1

     AND c.in_record_id IS NOT NULL',

     r.table_to_id,             

     r.table_to_api_name,       

     r.fk                      

);





END IF;





        ------------------------------------------------------------

        -- LOG

        ------------------------------------------------------------

        IF v_logs THEN

            RAISE NOTICE

            '[ac_requests_top_down] SQL=% bind=%',

            v_sql,

            p_master_key_id;

        END IF;





        ------------------------------------------------------------

        -- EXECUTE RECURSION

        ------------------------------------------------------------

        EXECUTE v_sql USING p_master_key_id;





    END LOOP;





    ------------------------------------------------------------

    -- LOG COMPLETE

    ------------------------------------------------------------

    IF v_logs THEN

        RAISE NOTICE

        '[ac_requests_top_down] COMPLETE table_id=% key_id=%',

        p_master_table_id,

        p_master_key_id;

    END IF;





END;

$function$