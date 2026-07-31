CREATE OR REPLACE FUNCTION public.ac_users_bottom_up(p_master_table_id bigint, p_master_key_id bigint DEFAULT NULL::bigint, p_row record DEFAULT NULL::record)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE

    v_logs boolean := COALESCE(NULLIF(current_setting('admin.acl_logs', true), ''), 'false')::boolean;

    v_result jsonb := '{}'::jsonb;



    r record;

    v_row_json    jsonb;

    v_parent_id   bigint;

    v_parent_json jsonb;

    v_table_id    bigint;

    v_sql text;



BEGIN



v_row_json := to_jsonb(p_row);



IF v_row_json = 'null'::jsonb THEN

    v_row_json := NULL;

END IF;



IF v_logs THEN

    RAISE NOTICE '[ac_users_bottom_up] START table_id=%, key_id=%, by_row=%',

        p_master_table_id,

        p_master_key_id,

        (v_row_json IS NOT NULL);

END IF;







v_table_id := COALESCE(

    (v_row_json->>'in_ref_master_table')::bigint,

    p_master_table_id

);





IF v_logs THEN

    RAISE NOTICE 

    '[ac_users_bottom_up] MODE=% table_id=% key_id=%',

    CASE WHEN v_row_json IS NOT NULL THEN 'ROW' ELSE 'KEY' END,

    v_table_id,

    COALESCE(p_master_key_id, (v_row_json->>'in_record_id')::bigint);

END IF;

    ------------------------------------------------------------

    -- EDGE DISCOVERY (COMMON)

    ------------------------------------------------------------

FOR r IN

(

          SELECT *

    FROM ( 



        --------------------------------------------------

        -- SINGLE-SELECT LOOKUP

        --------------------------------------------------

    

            SELECT      

            n1.ref_master_table_in_record_id AS table_from_id,

            table_from.table_api_name     AS table_from_api_name,

            n1.node_api_name              AS fk,

            table_to.in_record_id         AS table_to_id,

            table_to.table_api_name       AS table_to_api_name,

            m.permission,

            'One-Many Lookup' as node_data_type

       FROM master_table_access_control_users m

       JOIN master_table table_to ON table_to.in_record_id = m.ref_master_table_in_record_id_to

       JOIN master_node n1 ON n1.in_record_id = m.ref_master_node_in_record_id_from

       JOIN master_table table_from ON table_from.in_record_id = n1.ref_master_table_in_record_id

       WHERE n1.node_data_type = 'One-Many Lookup'

       AND   m.ref_master_table_in_record_id_to =  v_table_id



       UNION ALL



          --------------------------------------------------

          -- MULTI-SELECT LOOKUP

          --------------------------------------------------

            SELECT      

            n1.ref_master_table_in_record_id AS table_from_id,

            table_from.table_api_name     AS table_from_api_name,

            n2.node_api_name              AS fk,

            table_to.in_record_id         AS table_to_id,

            table_to.table_api_name       AS table_to_api_name,

            m.permission,

            'Many-One Lookup' as node_data_type

        FROM master_table_access_control_users m

        JOIN master_table table_to ON table_to.in_record_id = m.ref_master_table_in_record_id_to

        JOIN master_node n1 ON n1.in_record_id = m.ref_master_node_in_record_id_from

        JOIN master_table table_from ON table_from.in_record_id = n1.ref_master_table_in_record_id

        JOIN master_node n2 ON n1.ref_master_node_inverse_in_record_id = n2.in_record_id

       WHERE n1.node_data_type = 'Many-One Lookup'

        AND   m.ref_master_table_in_record_id_to =  v_table_id

        

            ) edges





)

LOOP



        ------------------------------------------------------------

        -- DETERMINE PARENT ID SOURCE

        ------------------------------------------------------------

        IF v_row_json IS NOT NULL THEN

            -- row-based resolution

            v_parent_id := (v_row_json->>r.fk)::bigint;



            IF v_parent_id IS NULL THEN

                CONTINUE;

            END IF;



            v_sql := format(

                'SELECT in_ref_master_users_id

                 FROM %I

                 WHERE in_record_id = $1',

                 r.table_from_api_name

            );



        ELSE

            -- direct key resolution

            IF r.node_data_type = 'One-Many Lookup' THEN



                v_sql :=

                'SELECT c.in_ref_master_users_id

                 FROM '||quote_ident(r.table_from_api_name)||' c

                 JOIN '||quote_ident(r.table_to_api_name)||' p

                   ON p.in_record_id = c.'||quote_ident(r.fk)||'

                 WHERE p.in_record_id = $1';



            ELSEIF r.node_data_type = 'Many-One Lookup' THEN



                v_sql :=

                'SELECT c.in_ref_master_users_id

                 FROM '||quote_ident(r.table_from_api_name)||' c

                 JOIN '||quote_ident(r.table_to_api_name)||' p

                   ON p.'||quote_ident(r.fk)||' = c.in_record_id

                 WHERE p.in_record_id = $1';

            END IF;



            v_parent_id := p_master_key_id;



        END IF;



        ------------------------------------------------------------

        -- EXECUTE

        ------------------------------------------------------------

EXECUTE format(

$$

SELECT COALESCE(

    jsonb_object_agg(key, value),

    '{}'::jsonb

)

FROM (

    SELECT key,

           jsonb_agg(DISTINCT elem) AS value

    FROM (

        SELECT key,

               jsonb_array_elements_text(value)::bigint AS elem

        FROM (

            SELECT jsonb_array_elements(

    COALESCE(

        jsonb_agg(in_ref_master_users_id) FILTER (WHERE in_ref_master_users_id IS NOT NULL),

        '[]'::jsonb

    )

) AS obj

            FROM (%s) x

        ) t

        CROSS JOIN LATERAL jsonb_each(t.obj)

    ) flat

    GROUP BY key

) final

$$,

v_sql

)

INTO v_parent_json

USING v_parent_id;





IF v_logs THEN

    RAISE NOTICE 

    '[ac_users_bottom_up] EDGE from=%(%), to=%(%), fk=%, type=% | source_key=% | parent_json=%',

        r.table_from_api_name,

        r.table_from_id,

        r.table_to_api_name,

        r.table_to_id,

        r.fk,

        r.node_data_type,

        v_parent_id,

        v_parent_json;

END IF;



/*IF v_parent_json IS NULL THEN

    CONTINUE;

END IF; */



IF v_parent_json = '{}'::jsonb THEN

    IF v_logs THEN

        RAISE NOTICE 

        '[ac_users_bottom_up] EMPTY DATA fk=% source_key=%',

        r.fk,

        v_parent_id;

    END IF;



    CONTINUE;

END IF;



        ------------------------------------------------------------

        -- MERGE JSON

        ------------------------------------------------------------

        v_result :=

        (

            SELECT COALESCE(jsonb_object_agg(perm, ids),'{}'::jsonb)

            FROM (

                SELECT perm,

                       jsonb_agg(DISTINCT uid ORDER BY uid) ids

                FROM (

                    SELECT key perm,

                           jsonb_array_elements_text(value)::bigint uid

                    FROM jsonb_each(v_result)



                    UNION ALL



                    SELECT perm_val,

                           jsonb_array_elements_text(value)::bigint

                    FROM jsonb_each(v_parent_json)

                    CROSS JOIN LATERAL unnest(r.permission) perm_val

                    WHERE perm_val IN ('Select','Update','Delete')

                ) merged

                GROUP BY perm

            ) final

        );



IF v_logs THEN

    RAISE NOTICE 

    '[ac_users_bottom_up] MERGED fk=% => result=%',

    r.fk,

    v_result;

END IF;



    END LOOP;







    RETURN v_result;



END;

$function$