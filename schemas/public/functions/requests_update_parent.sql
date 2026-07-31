CREATE OR REPLACE FUNCTION public.requests_update_parent()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    -- Module

    v_child_module          text;

    v_parent_module         text;

    v_mod                   text;



    -- JSON config

    v_json                  jsonb;

    v_parent_module_json    jsonb;

    v_child_modules_json    jsonb;



    -- SKU

    v_parent_sku            bigint;

    v_child_sku             bigint;

    v_parent_allow_all_sku  boolean := false;



    -- Hierarchy

    v_cursor                bigint;

    v_last_parent           bigint := NULL;

    v_new_root              bigint;

BEGIN

    ------------------------------------------------------------------

    -- 1.0) SELF-PARENT VALIDATION (HARD STOP)

    ------------------------------------------------------------------

    IF NEW.immediate_parent = NEW.ref_requests_record_id THEN

        RAISE EXCEPTION

            'Hierarchy violation: request % cannot be its own parent',

            NEW.ref_requests_record_id;

    END IF;



------------------------------------------------------------------

-- 1.05) QUICK BACK-EDGE CYCLE CHECK (FAST FAIL)

-- Prevents: A -> B AND B -> A

------------------------------------------------------------------

IF EXISTS (

    SELECT 1

    FROM public.requests_services

    WHERE ref_requests_record_id = NEW.immediate_parent

      AND immediate_parent = NEW.ref_requests_record_id

)

OR EXISTS (

    SELECT 1

    FROM public.requests_staffing

    WHERE ref_requests_record_id = NEW.immediate_parent

      AND immediate_parent = NEW.ref_requests_record_id

)

THEN

    RAISE EXCEPTION

        'Cycle detected: % cannot be re-parented under % (back-edge)',

        NEW.ref_requests_record_id,

        NEW.immediate_parent;

END IF;





    ------------------------------------------------------------------

    -- 1.1) SKIP EXPENSIVE LOGIC IF PARENT DID NOT CHANGE

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE'

    AND NEW.immediate_parent IS NOT DISTINCT FROM OLD.immediate_parent THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- 1) CHILD MODULE

    ------------------------------------------------------------------

    SELECT module

      INTO v_child_module

      FROM public.requests

     WHERE in_record_id = NEW.ref_requests_record_id;



    IF v_child_module IS NULL THEN

        RAISE EXCEPTION

            'Invalid child request id %',

            NEW.ref_requests_record_id;

    END IF;



    v_child_module := initcap(lower(trim(v_child_module)));



    ------------------------------------------------------------------

    -- 2) LOAD ACTIONABLE JSON

    ------------------------------------------------------------------

    SELECT actionable_config

      INTO v_json

      FROM public.actionables_execution_metadata

     ORDER BY in_record_id DESC

     LIMIT 1;



    IF v_json IS NULL THEN

        RAISE EXCEPTION 'Missing actionable_config';

    END IF;



    ------------------------------------------------------------------

    -- 3) PARENT MODULE

    ------------------------------------------------------------------

    SELECT module

      INTO v_parent_module

      FROM public.requests

     WHERE in_record_id = NEW.immediate_parent;



    IF v_parent_module IS NULL THEN

        RAISE EXCEPTION

            'Invalid immediate_parent %',

            NEW.immediate_parent;

    END IF;



    v_parent_module := initcap(lower(trim(v_parent_module)));



    ------------------------------------------------------------------

    -- 4) JSON MODULE VALIDATION

    ------------------------------------------------------------------

    v_parent_module_json := v_json #> ARRAY['module', v_parent_module];



    IF v_parent_module_json IS NULL THEN

        RAISE EXCEPTION

            'Parent module % not found in configuration',

            v_parent_module;

    END IF;



    v_child_modules_json := v_parent_module_json -> 'child_modules';



    IF v_child_modules_json IS NULL THEN

        RAISE EXCEPTION

            'Configuration error: missing child_modules for %',

            v_parent_module;

    END IF;



    IF NOT EXISTS (

        SELECT 1

        FROM jsonb_array_elements_text(v_child_modules_json) AS t(val)

        WHERE initcap(lower(trim(t.val))) = v_child_module

    ) THEN

        RAISE EXCEPTION

            'Child module % not allowed under parent module %',

            v_child_module,

            v_parent_module;

    END IF;



   ------------------------------------------------------------------

-- 5) ROOT RESOLUTION (INHERIT FROM PARENT)

------------------------------------------------------------------

IF v_parent_module = 'Problem' THEN

    NEW.root_parent := NEW.immediate_parent;

ELSE

    SELECT root_parent

    INTO NEW.root_parent

    FROM public.requests_services

    WHERE ref_requests_record_id = NEW.immediate_parent;



    IF NOT FOUND THEN

        SELECT root_parent

        INTO NEW.root_parent

        FROM public.requests_staffing

        WHERE ref_requests_record_id = NEW.immediate_parent;

    END IF;



    IF NEW.root_parent IS NULL THEN

        RAISE EXCEPTION

            'Cannot resolve root_parent from parent %',

            NEW.immediate_parent;

    END IF;

END IF;



    ------------------------------------------------------------------

    -- 6) SKU VALIDATION (ONLY WHEN PARENT = SERVICES)

    ------------------------------------------------------------------

    IF v_parent_module <> 'Services' THEN

        RETURN NEW;

    END IF;



    SELECT ref_services_sku

      INTO v_parent_sku

      FROM public.requests_services

     WHERE ref_requests_record_id = NEW.immediate_parent;



    SELECT ref_services_sku

      INTO v_child_sku

      FROM public.requests_services

     WHERE ref_requests_record_id = NEW.ref_requests_record_id;



    IF v_parent_sku IS NULL OR v_child_sku IS NULL THEN

        RETURN NEW;

    END IF;



    SELECT COALESCE(allow_all_sku_as_child, false)

      INTO v_parent_allow_all_sku

      FROM public.services_sku

     WHERE in_record_id = v_parent_sku;



    IF NOT v_parent_allow_all_sku THEN

        IF NOT EXISTS (

            SELECT 1

            FROM public.services_sku_dependency

            WHERE ref_services_sku_parent = v_parent_sku

              AND ref_services_sku_child  = v_child_sku

        ) THEN

            RAISE EXCEPTION

                'SKU Dependency Error: parent SKU % does NOT allow child SKU %',

                v_parent_sku,

                v_child_sku;

        END IF;

    END IF;



    RETURN NEW;

END;

$function$