CREATE OR REPLACE FUNCTION public.app_view_requests_hierarchy()
 RETURNS TABLE(request_id bigint, immediate_parent bigint, root_parent bigint, module text, level integer, full_path bigint[], all_parents bigint[], immediate_children bigint[], all_children bigint[], all_related bigint[])
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
 SET row_security TO 'off'
AS $function$



WITH RECURSIVE parent_edges AS (



    SELECT

        rs.immediate_parent::bigint,

        rs.ref_requests_record_id::bigint AS child_id

    FROM requests_services rs



    UNION ALL



    SELECT

        rf.immediate_parent::bigint,

        rf.ref_requests_record_id::bigint

    FROM requests_staffing rf



    UNION 



    SELECT

        rf.immediate_parent::bigint,

        rf.ref_requests_in_record_id::bigint

    FROM requests_sku_roles rf



),



request_tree AS (





    -- root nodes

    SELECT

        r.in_record_id AS request_id,

        NULL::bigint AS parent_id,

        r.in_record_id AS root_parent,

        r.module,

        1 AS level,

        ARRAY[r.in_record_id] AS path

    FROM requests r

    WHERE r.module = 'Problem'



    UNION ALL



    -- recursive children

    SELECT

        pe.child_id,

        pe.immediate_parent,

        rt.root_parent,

        r.module,

        rt.level + 1,

        rt.path || pe.child_id

    FROM request_tree rt

    JOIN parent_edges pe

        ON pe.immediate_parent = rt.request_id

    JOIN requests r

        ON r.in_record_id = pe.child_id

    WHERE NOT pe.child_id = ANY(rt.path)



),



children_agg AS (



    SELECT

        parent_id,

        array_agg(request_id ORDER BY request_id) AS immediate_children

    FROM request_tree

    WHERE parent_id IS NOT NULL

    GROUP BY parent_id



),



descendants_agg AS (



    SELECT

        t1.request_id,

        array_agg(c.request_id ORDER BY c.level, c.request_id) AS all_children

    FROM request_tree t1

    JOIN request_tree c

        ON c.root_parent = t1.root_parent

        AND t1.request_id = ANY(c.path)

        AND c.request_id <> t1.request_id

    GROUP BY t1.request_id



)



SELECT

    t.request_id,

    t.parent_id AS immediate_parent,

    t.root_parent,

    t.module,

    t.level,

    t.path AS full_path,



    t.path[1:cardinality(t.path)-1] AS all_parents,



    COALESCE(

        ca.immediate_children,

        ARRAY[]::bigint[]

    ),



    COALESCE(

        da.all_children,

        ARRAY[]::bigint[]

    ),



    ARRAY(

        SELECT DISTINCT x

        FROM unnest(

            t.path[1:cardinality(t.path)-1]

            || COALESCE(da.all_children, ARRAY[]::bigint[])

        ) AS u(x)

        ORDER BY x

    ) AS all_related



FROM request_tree t

LEFT JOIN children_agg ca

    ON ca.parent_id = t.request_id

LEFT JOIN descendants_agg da

    ON da.request_id = t.request_id



ORDER BY

    t.root_parent,

    t.level,

    t.path;



$function$