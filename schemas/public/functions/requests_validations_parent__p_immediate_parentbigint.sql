CREATE OR REPLACE FUNCTION public.requests_validations_parent(p_immediate_parent bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 STABLE
AS $function$

DECLARE

    v_parent_module text;

    v_root_parent   bigint;

BEGIN

    ------------------------------------------------------------------

    -- Validate parent exists

    ------------------------------------------------------------------

    SELECT module

    INTO v_parent_module

    FROM public.requests

    WHERE in_record_id = p_immediate_parent;



    IF v_parent_module IS NULL THEN

        RAISE EXCEPTION

            'Invalid immediate_parent %',

            p_immediate_parent;

    END IF;



    ------------------------------------------------------------------

    -- If parent is Problem ΓåÆ it is the root

    ------------------------------------------------------------------

    IF v_parent_module = 'Problem' THEN

        RETURN p_immediate_parent;

    END IF;



    ------------------------------------------------------------------

    -- Otherwise inherit root from parent

    -- (Services or Staffing or Roles)

    ------------------------------------------------------------------

    SELECT root_parent

    INTO v_root_parent

    FROM public.requests_services

    WHERE ref_requests_record_id = p_immediate_parent;



    IF NOT FOUND THEN

        SELECT root_parent

        INTO v_root_parent

        FROM public.requests_staffing

        WHERE ref_requests_record_id = p_immediate_parent;

    END IF;



    IF NOT FOUND THEN

        SELECT root_parent

        INTO v_root_parent

        FROM public.requests_sku_roles

        WHERE ref_requests_in_record_id = p_immediate_parent;

    END IF;



    IF v_root_parent IS NULL THEN

        RAISE EXCEPTION

            'Parent % has no resolved root_parent',

            p_immediate_parent;

    END IF;



    ------------------------------------------------------------------

    -- Final safety: root must be Problem

    ------------------------------------------------------------------

    PERFORM 1

    FROM public.requests

    WHERE in_record_id = v_root_parent

      AND module = 'Problem';



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Resolved root_parent % is not a Problem',

            v_root_parent;

    END IF;



    RETURN v_root_parent;

END;

$function$