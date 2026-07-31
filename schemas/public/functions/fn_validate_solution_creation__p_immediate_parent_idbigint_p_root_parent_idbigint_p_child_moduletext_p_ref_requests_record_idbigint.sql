CREATE OR REPLACE FUNCTION public.fn_validate_solution_creation(p_immediate_parent_id bigint, p_root_parent_id bigint, p_child_module text, p_ref_requests_record_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

DECLARE

    v_parent                    public.requests%ROWTYPE;

    v_child_request             public.requests%ROWTYPE;



    v_config                    jsonb;

    v_parent_module_node        jsonb;

    v_child_solutions           jsonb;



    -- SKU IDs

    v_parent_sku                bigint;

    v_child_sku                 bigint;



    -- override flags

    v_parent_allow_all_child    boolean;

    v_child_allow_all_parent    boolean;



    -- normalized modules

    v_parent_module             text;

    v_child_module              text := initcap(lower(trim(p_child_module)));



BEGIN



    ------------------------------------------------------------------

    -- 1) VALIDATE IMMEDIATE PARENT EXISTS

    ------------------------------------------------------------------

    SELECT *

    INTO v_parent

    FROM public.requests

    WHERE in_record_id = p_immediate_parent_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid immediate_parent request_id=%',

            p_immediate_parent_id;

    END IF;



    v_parent_module := initcap(lower(trim(v_parent.module)));





    ------------------------------------------------------------------

    -- 2) VALIDATE CHILD REQUEST EXISTS

    ------------------------------------------------------------------

    SELECT *

    INTO v_child_request

    FROM public.requests

    WHERE in_record_id = p_ref_requests_record_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Invalid child request_id=%',

            p_ref_requests_record_id;

    END IF;





    ------------------------------------------------------------------

    -- 3) PREVENT SELF-PARENTING

    ------------------------------------------------------------------

    IF p_immediate_parent_id = p_ref_requests_record_id THEN

        RAISE EXCEPTION

            'Hierarchy violation: request % cannot be its own parent',

            p_ref_requests_record_id;

    END IF;





    ------------------------------------------------------------------

    -- 4) LOAD CONFIGURATION

    ------------------------------------------------------------------

    SELECT actionable_config

    INTO v_config

    FROM public.actionables_execution_metadata

    ORDER BY in_record_id DESC

    LIMIT 1;



    IF v_config IS NULL THEN

        RAISE EXCEPTION

            'Missing actionable_config metadata';

    END IF;





    ------------------------------------------------------------------

    -- 5) VALIDATE PARENT MODULE EXISTS IN CONFIG

    ------------------------------------------------------------------

    v_parent_module_node :=

        v_config

        -> 'Request'

        -> 'Sub Request Type'

        -> v_parent_module;



    IF v_parent_module_node IS NULL THEN

        RAISE EXCEPTION

            'Configuration error: missing parent module config for module=%',

            v_parent_module;

    END IF;





    ------------------------------------------------------------------

    -- 6) VALIDATE CHILD MODULE ALLOWED

    ------------------------------------------------------------------

    v_child_solutions :=

        v_parent_module_node -> 'Child Solutions';



    IF v_child_solutions IS NULL THEN

        RAISE EXCEPTION

            'Configuration error: missing Child Solutions config for module=%',

            v_parent_module;

    END IF;



    IF NOT EXISTS (

        SELECT 1

        FROM jsonb_array_elements_text(v_child_solutions) s(solution)

        WHERE initcap(lower(trim(s.solution))) = v_child_module

    ) THEN

        RAISE EXCEPTION

            'Child module "%" not allowed under parent module "%"',

            v_child_module,

            v_parent_module;

    END IF;





    ------------------------------------------------------------------

    -- 7) VALIDATE CHILD REQUEST MODULE MATCHES EXPECTATION

    ------------------------------------------------------------------

    IF initcap(lower(trim(v_child_request.module))) <> v_child_module THEN

        RAISE EXCEPTION

            'Child request module mismatch. Expected "%", got "%"',

            v_child_module,

            v_child_request.module;

    END IF;





    ------------------------------------------------------------------

    -- 8) SKU VALIDATION ONLY FOR SERVICES MODULE

    ------------------------------------------------------------------

    IF v_parent_module <> 'Services' THEN

        RETURN;

    END IF;





    ------------------------------------------------------------------

    -- 9) LOAD PARENT SKU

    ------------------------------------------------------------------

    SELECT ref_services_sku

    INTO v_parent_sku

    FROM public.requests_services

    WHERE ref_requests_record_id = p_immediate_parent_id

    LIMIT 1;



    IF v_parent_sku IS NULL THEN

        RETURN;

    END IF;





    ------------------------------------------------------------------

    -- 10) LOAD CHILD SKU

    ------------------------------------------------------------------

    SELECT ref_services_sku

    INTO v_child_sku

    FROM public.requests_services

    WHERE ref_requests_record_id = p_ref_requests_record_id

    LIMIT 1;



    IF v_child_sku IS NULL THEN

        RETURN;

    END IF;





    ------------------------------------------------------------------

    -- 11) VALIDATE BOTH SKUs EXIST + LOAD OVERRIDE FLAGS

    ------------------------------------------------------------------

    SELECT allow_all_sku_as_child

    INTO v_parent_allow_all_child

    FROM public.services_sku

    WHERE in_record_id = v_parent_sku;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Parent SKU does not exist. sku_id=%',

            v_parent_sku;

    END IF;





    SELECT allow_all_sku_as_parent

    INTO v_child_allow_all_parent

    FROM public.services_sku

    WHERE in_record_id = v_child_sku;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Child SKU does not exist. sku_id=%',

            v_child_sku;

    END IF;





    ------------------------------------------------------------------

    -- 12) ENFORCE DEPENDENCY IF BOTH SIDES RESTRICT

    ------------------------------------------------------------------

    IF NOT COALESCE(v_parent_allow_all_child,false)

    AND NOT COALESCE(v_child_allow_all_parent,false)

    THEN



        IF NOT EXISTS (

            SELECT 1

            FROM public.services_sku_dependency

            WHERE ref_services_sku_parent = v_parent_sku

            AND ref_services_sku_child  = v_child_sku

        ) THEN



            RAISE EXCEPTION

                'SKU dependency violation: parent SKU % does not allow child SKU %',

                v_parent_sku,

                v_child_sku;



        END IF;



    END IF;





    ------------------------------------------------------------------

    -- SUCCESS

    ------------------------------------------------------------------

    RETURN;



END;

$function$