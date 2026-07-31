CREATE OR REPLACE FUNCTION public.fn_requests_dependency_diagnostics(in_request_id bigint, in_module text, in_parent_module text, in_root_module text, in_edge_source_table text, in_edge_type text, in_edge_root_parent bigint, in_computed_root_parent bigint)
 RETURNS TABLE(has_dependency_row boolean, has_valid_dependency_row boolean, invalid_dependency_row boolean, invalid_dependency_reason text, invalid_dependency_reasons text[])
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_has_row boolean := false;

    v_has_valid boolean := false;

    v_reasons text[] := ARRAY[]::text[];

    v_reason text := NULL;



    v_has_services_edge boolean := false;

    v_has_staffing_edge boolean := false;

BEGIN

    /* non dependent modules */

    IF in_module IS NULL OR in_module NOT IN ('Services','Staffing') THEN

        RETURN QUERY

        SELECT true, true, false, NULL::text, ARRAY[]::text[];

        RETURN;

    END IF;



    /* detect edge row existence in BOTH tables */

    SELECT EXISTS (

        SELECT 1 FROM public.requests_services rs

        WHERE rs.ref_requests_record_id = in_request_id

    )

    INTO v_has_services_edge;



    SELECT EXISTS (

        SELECT 1 FROM public.requests_staffing rf

        WHERE rf.ref_requests_record_id = in_request_id

    )

    INTO v_has_staffing_edge;



    /* severe corruption */

    IF v_has_services_edge AND v_has_staffing_edge THEN

        v_reasons := v_reasons || ARRAY['EDGE_ROWS_IN_BOTH_TABLES'];

    END IF;



    /* expected table existence */

    IF in_module = 'Services' THEN

        v_has_row := v_has_services_edge;

        IF (NOT v_has_row) AND v_has_staffing_edge THEN

            v_reasons := v_reasons || ARRAY['EDGE_ROW_IN_WRONG_TABLE'];

        END IF;



    ELSIF in_module = 'Staffing' THEN

        v_has_row := v_has_staffing_edge;

        IF (NOT v_has_row) AND v_has_services_edge THEN

            v_reasons := v_reasons || ARRAY['EDGE_ROW_IN_WRONG_TABLE'];

        END IF;

    END IF;



    IF NOT v_has_row THEN

        v_reasons := v_reasons || ARRAY['NO_EDGE_ROW'];

    END IF;



    /* module info availability */

    IF v_has_row AND (in_root_module IS NULL OR btrim(in_root_module) = '') THEN

        v_reasons := v_reasons || ARRAY['ROOT_MODULE_UNKNOWN'];

    END IF;



    IF v_has_row AND (in_parent_module IS NULL OR btrim(in_parent_module) = '') THEN

        v_reasons := v_reasons || ARRAY['PARENT_MODULE_UNKNOWN'];

    END IF;



    /* validity evaluation */

    IF in_module = 'Services' THEN

        v_has_valid :=

            v_has_row

            AND NOT (v_has_services_edge AND v_has_staffing_edge)

            AND COALESCE(in_root_module, '') = 'Problem'

            AND COALESCE(in_parent_module, '') IN ('Problem','Services')

            AND COALESCE(in_edge_source_table, '') = 'requests_services'

            AND COALESCE(in_edge_type, '') = 'Services';



    ELSIF in_module = 'Staffing' THEN

        v_has_valid :=

            v_has_row

            AND NOT (v_has_services_edge AND v_has_staffing_edge)

            AND COALESCE(in_root_module, '') = 'Problem'

            AND COALESCE(in_parent_module, '') IN ('Problem','Staffing')

            AND COALESCE(in_edge_source_table, '') = 'requests_staffing'

            AND COALESCE(in_edge_type, '') = 'Staffing';

    END IF;



    /* wrong edge table based on view values */

    IF v_has_row AND in_edge_source_table IS NOT NULL THEN

        IF (in_module = 'Services' AND in_edge_source_table <> 'requests_services')

           OR (in_module = 'Staffing' AND in_edge_source_table <> 'requests_staffing') THEN

            v_reasons := v_reasons || ARRAY['WRONG_EDGE_TABLE'];

        END IF;

    END IF;



    /* root must be problem */

    IF v_has_row AND in_root_module IS NOT NULL AND in_root_module <> 'Problem' THEN

        v_reasons := v_reasons || ARRAY['ROOT_NOT_PROBLEM'];

    END IF;



    /* parent allowed */

    IF v_has_row AND in_parent_module IS NOT NULL THEN

        IF (in_module = 'Services' AND in_parent_module NOT IN ('Problem','Services'))

           OR (in_module = 'Staffing' AND in_parent_module NOT IN ('Problem','Staffing')) THEN

            v_reasons := v_reasons || ARRAY['PARENT_NOT_ALLOWED'];

        END IF;

    END IF;



    /* edge root mismatch */

    IF v_has_row

       AND in_edge_root_parent IS NOT NULL

       AND in_computed_root_parent IS NOT NULL

       AND in_edge_root_parent <> in_computed_root_parent THEN

        v_reasons := v_reasons || ARRAY['EDGE_ROOT_PARENT_MISMATCH'];

    END IF;



    /* edge type mismatch */

    IF v_has_row AND in_edge_type IS NOT NULL AND in_edge_type <> in_module THEN

        v_reasons := v_reasons || ARRAY['EDGE_CHILD_MODULE_MISMATCH'];

    END IF;



    /* primary reason (priority order) */

    v_reason :=

        CASE

            WHEN 'EDGE_ROWS_IN_BOTH_TABLES' = ANY(v_reasons) THEN 'EDGE_ROWS_IN_BOTH_TABLES'

            WHEN 'EDGE_ROW_IN_WRONG_TABLE' = ANY(v_reasons) THEN 'EDGE_ROW_IN_WRONG_TABLE'

            WHEN 'NO_EDGE_ROW' = ANY(v_reasons) THEN 'NO_EDGE_ROW'

            WHEN 'WRONG_EDGE_TABLE' = ANY(v_reasons) THEN 'WRONG_EDGE_TABLE'

            WHEN 'EDGE_CHILD_MODULE_MISMATCH' = ANY(v_reasons) THEN 'EDGE_CHILD_MODULE_MISMATCH'

            WHEN 'EDGE_ROOT_PARENT_MISMATCH' = ANY(v_reasons) THEN 'EDGE_ROOT_PARENT_MISMATCH'

            WHEN 'ROOT_NOT_PROBLEM' = ANY(v_reasons) THEN 'ROOT_NOT_PROBLEM'

            WHEN 'PARENT_NOT_ALLOWED' = ANY(v_reasons) THEN 'PARENT_NOT_ALLOWED'

            WHEN 'ROOT_MODULE_UNKNOWN' = ANY(v_reasons) THEN 'ROOT_MODULE_UNKNOWN'

            WHEN 'PARENT_MODULE_UNKNOWN' = ANY(v_reasons) THEN 'PARENT_MODULE_UNKNOWN'

            ELSE NULL

        END;



    RETURN QUERY

    SELECT

        v_has_row,

        v_has_valid,

        (v_has_row AND NOT v_has_valid) OR (NOT v_has_row),

        v_reason,

        v_reasons;

END;

$function$