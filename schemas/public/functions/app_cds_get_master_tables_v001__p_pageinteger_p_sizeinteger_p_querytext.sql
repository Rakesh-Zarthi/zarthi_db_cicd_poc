CREATE OR REPLACE FUNCTION public.app_cds_get_master_tables_v001(p_page integer DEFAULT 1, p_size integer DEFAULT 10, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$

DECLARE

    v_offset       integer;

    v_total_count  integer;

    v_total_pages  integer;

BEGIN

    p_page := GREATEST(COALESCE(p_page, 1), 1);

    p_size := GREATEST(COALESCE(p_size, 10), 1);

 

    v_offset := (p_page - 1) * p_size;

 

    SELECT COUNT(*)

    INTO v_total_count

    FROM master_table mt

    WHERE

        mt.admin_restricted = false

        AND (

            p_query IS NULL

            OR p_query = ''

            OR mt.table_name ILIKE '%' || p_query || '%'

            OR mt.table_api_name ILIKE '%' || p_query || '%'

        );

 

    v_total_pages :=

        CASE

            WHEN v_total_count = 0 THEN 0

            ELSE CEIL(v_total_count::numeric / p_size)::integer

        END;

 

    RETURN jsonb_build_object(

        'content',

        COALESCE(

            (

                SELECT jsonb_agg(

                    jsonb_build_object(

                        'id', in_record_id,

                        'name', table_name,

                        'apiName', table_api_name

                    )

                    ORDER BY table_name

                )

                FROM (

                    SELECT

                        in_record_id,

                        table_name,

                        table_api_name

                    FROM master_table mt

                    WHERE

                        mt.admin_restricted = false

                        AND (

                            p_query IS NULL

                            OR p_query = ''

                            OR mt.table_name ILIKE '%' || p_query || '%'

                            OR mt.table_api_name ILIKE '%' || p_query || '%'

                        )

                    ORDER BY table_name

                    LIMIT p_size

                    OFFSET v_offset

                ) t

            ),

            '[]'::jsonb

        ),

        'pageNumber', p_page,

        'pageSize', p_size,

        'totalPages', v_total_pages,

        'totalCount', v_total_count

    );

END;

$function$