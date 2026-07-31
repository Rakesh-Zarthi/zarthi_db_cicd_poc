CREATE OR REPLACE FUNCTION public.validates_actionables_steps_requests(p_new_row actionables_steps, p_step_owner_rule text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
v_actionable_name      text;
v_request_id           bigint;
v_immediate_parent_req bigint;
v_rule                 text;
BEGIN
------------------------------------------------------------------
-- Normalize rule
------------------------------------------------------------------
v_rule := initcap(lower(trim(p_step_owner_rule)));


------------------------------------------------------------------
-- Resolve actionable + request
------------------------------------------------------------------
SELECT a.actionable_name,
       a.request_subject
  INTO v_actionable_name,
       v_request_id
  FROM public.actionables a
 WHERE a.in_record_id = p_new_row.ref_actionables_in_record_id;

IF v_request_id IS NULL THEN
    RAISE EXCEPTION
        'Request_Based step requires actionable with request_subject'
        USING ERRCODE = '23514';
END IF;

------------------------------------------------------------------
-- Assigned request mandatory
------------------------------------------------------------------
IF p_new_row.ref_requests_in_record_id_assigned_to IS NULL THEN
    RAISE EXCEPTION
        'Request_Based step requires ref_requests_in_record_id_assigned_to (actionable "%", step %)',
        v_actionable_name,
        p_new_row.step_no
        USING ERRCODE = '23514';
END IF;

------------------------------------------------------------------
-- Owner = Current Request
------------------------------------------------------------------
IF v_rule = 'Request Owner' THEN

    IF p_new_row.ref_requests_in_record_id_assigned_to <> v_request_id THEN
        RAISE EXCEPTION
            'For Request Owner, assigned request must be %, got % (actionable "%", step %)',
            v_request_id,
            p_new_row.ref_requests_in_record_id_assigned_to,
            v_actionable_name,
            p_new_row.step_no
            USING ERRCODE = '23514';
    END IF;

------------------------------------------------------------------
-- Owner = Immediate Parent
------------------------------------------------------------------
ELSIF v_rule = 'Immediate Parent Request Owner' THEN

    SELECT immediate_parent
      INTO v_immediate_parent_req
      FROM (

            ------------------------------------------------------------------
            -- Services
            ------------------------------------------------------------------
            SELECT immediate_parent
            FROM public.requests_services
            WHERE ref_requests_record_id = v_request_id

            UNION ALL

            ------------------------------------------------------------------
            -- Staffing
            ------------------------------------------------------------------
            SELECT immediate_parent
            FROM public.requests_staffing
            WHERE ref_requests_record_id = v_request_id

            UNION ALL

            ------------------------------------------------------------------
            -- Roles
            ------------------------------------------------------------------
            SELECT immediate_parent
            FROM public.requests_sku_roles
            WHERE ref_requests_in_record_id = v_request_id

      ) p
     LIMIT 1;

    IF v_immediate_parent_req IS NULL THEN
        RAISE EXCEPTION
            'Immediate parent request not found (actionable "%", step %)',
            v_actionable_name,
            p_new_row.step_no
            USING ERRCODE = '23514';
    END IF;

    IF p_new_row.ref_requests_in_record_id_assigned_to <> v_immediate_parent_req THEN
        RAISE EXCEPTION
            'Assigned request must be immediate parent %, got % (actionable "%", step %)',
            v_immediate_parent_req,
            p_new_row.ref_requests_in_record_id_assigned_to,
            v_actionable_name,
            p_new_row.step_no
            USING ERRCODE = '23514';
    END IF;

------------------------------------------------------------------
-- Unsupported rule
------------------------------------------------------------------
ELSE
    RAISE EXCEPTION
        'Unsupported Step Owner rule "%" for Request_Based step',
        p_step_owner_rule
        USING ERRCODE = '23514';
END IF;

END;
$function$