CREATE OR REPLACE FUNCTION public.app_add_orders_step_2_complete_v_0_0_1(p_actionable_step_id bigint, p_request_id bigint, p_response text, p_json jsonb, p_step_3_json jsonb)
 RETURNS TABLE(actionable_id bigint, step_2_id bigint, step_3_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Logging & Session

------------------------------------------------------------------

v_run_id text;

v_txid bigint;

v_user_uuid uuid;

v_created_by bigint;



------------------------------------------------------------------

-- Step 2

------------------------------------------------------------------

v_actionable_id bigint;

v_step_status text;

v_step_no integer;



------------------------------------------------------------------

-- Request

------------------------------------------------------------------

v_request_subject bigint;

v_request_id bigint;



------------------------------------------------------------------

-- Customer Resolution

------------------------------------------------------------------

v_bill_to text;

v_ref_users_in_record_id_customer bigint;



------------------------------------------------------------------

-- Step 3

------------------------------------------------------------------

v_step_3_status text;

v_step_3_id bigint;



------------------------------------------------------------------

-- Auto Complete Logic

------------------------------------------------------------------

v_step_2_request_id bigint;

v_step_2_request_owner bigint;

v_step_3_owner bigint;

v_step_3_complete_json jsonb;

------------------------------------------------------------------

-- Inputs

------------------------------------------------------------------

p_reason text;



BEGIN



------------------------------------------------------------------

-- Generate run_id and txid for logging

------------------------------------------------------------------

v_run_id := substring(md5(random()::text), 1, 8);

v_txid := txid_current();



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_actionable_step_id IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'actionable_step_id is mandatory', now();

END IF;



IF p_request_id IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'request_id is mandatory', now();

END IF;



IF p_response IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'response is mandatory', now();

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'json is mandatory', now();

END IF;



------------------------------------------------------------------

-- Normalize and Validate Response

------------------------------------------------------------------

p_response := upper(trim(p_response));



IF p_response NOT IN ('APPROVE', 'REJECT') THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'response must be APPROVE or REJECT', now();

END IF;



------------------------------------------------------------------

-- Extract reason from metadata

------------------------------------------------------------------

p_reason := trim(p_json -> 'metadata' ->> 'reason');



IF p_response = 'REJECT' AND COALESCE(p_reason, '') = '' THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'reason is mandatory for REJECT', now();

END IF;



------------------------------------------------------------------

-- JSON Validation

-- Completed step must have metadata

-- draftedData must be null

------------------------------------------------------------------

IF p_json -> 'metadata' IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'metadata is mandatory in JSON', now();

END IF;



IF p_json -> 'draftedData' IS NOT NULL AND p_json -> 'draftedData' != '{}'::jsonb THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][VALIDATION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'draftedData must be null or {} for completed step', now();

END IF;



------------------------------------------------------------------

-- Resolve Session User

------------------------------------------------------------------

v_user_uuid := current_setting('app.CURRENT_USER_ID', true)::uuid;



SELECT u.in_record_id

INTO v_created_by

FROM public.users u

WHERE u.user_id = v_user_uuid;



IF v_created_by IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][SESSION][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Unable to resolve session user', now();

END IF;



------------------------------------------------------------------

-- Resolve Step 2

------------------------------------------------------------------

SELECT

    ast.ref_actionables_in_record_id,

    ast.step_no,

    ast.status,

    a.request_subject

INTO

    v_actionable_id,

    v_step_no,

    v_step_status,

    v_request_subject

FROM public.actionables_steps ast

INNER JOIN public.actionables a

    ON a.in_record_id = ast.ref_actionables_in_record_id

WHERE ast.in_record_id = p_actionable_step_id;



IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][STEP_RESOLVE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Invalid actionable step id: ' || p_actionable_step_id, now();

END IF;



------------------------------------------------------------------

-- Validate Step

------------------------------------------------------------------

IF v_step_no <> 2 THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Only Step 2 can be completed through this', now();

END IF;



IF v_step_status <> 'Open' THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step 2 must be Open. Current status = ' || v_step_status, now();

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][STEP_VALIDATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step does not belong to request ' || p_request_id, now();

END IF;



v_request_id := p_request_id;



------------------------------------------------------------------

-- Resolve Bill To

------------------------------------------------------------------

SELECT sku_roles.bill_to

INTO v_bill_to

FROM public.requests_sku_roles rsr

INNER JOIN public.services_sku_roles sku_roles

    ON sku_roles.in_record_id = rsr.ref_services_sku_roles_in_record_id

WHERE rsr.ref_requests_in_record_id = v_request_id;



IF v_bill_to IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][BILL_TO][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Bill To configuration not found for request ' || v_request_id, now();

END IF;



------------------------------------------------------------------

-- Resolve Customer User

------------------------------------------------------------------

SELECT

    CASE

        WHEN v_bill_to = 'Problem Owner'

            THEN r_root.owner

        WHEN v_bill_to = 'Individual'

            THEN u_roles_ind.in_record_id

        WHEN v_bill_to = 'Corporate Unit'

            THEN u_roles_corp.in_record_id

    END

INTO

    v_ref_users_in_record_id_customer

FROM public.requests_sku_roles rsr

INNER JOIN public.services_sku_roles sku_roles

    ON sku_roles.in_record_id = rsr.ref_services_sku_roles_in_record_id

LEFT JOIN public.users u_roles_ind

    ON u_roles_ind.in_record_id = sku_roles.ref_users_in_record_id_bill_to

LEFT JOIN public.practices p_roles

    ON p_roles.in_record_id = sku_roles.ref_practices_in_record_id_bill_to

LEFT JOIN public.users u_roles_corp

    ON u_roles_corp.in_record_id = p_roles.corporate_lead

LEFT JOIN public.requests r_root

    ON r_root.in_record_id = rsr.root_parent

WHERE rsr.ref_requests_in_record_id = v_request_id;



IF v_ref_users_in_record_id_customer IS NULL THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][CUSTOMER_RESOLVE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Unable to resolve customer owner', now();

END IF;



------------------------------------------------------------------

-- Prevent Duplicate Step 3

------------------------------------------------------------------

IF EXISTS (

    SELECT 1

    FROM public.actionables_steps ast

    WHERE ast.ref_actionables_in_record_id = v_actionable_id

      AND ast.step_no = 3

)

THEN

    RAISE EXCEPTION '[STEP_2_COMPLETE][STEP_3_CREATE][ERROR] run_id=% txid=% reason=% ts=%',

        v_run_id, v_txid, 'Step 3 already exists for actionable ' || v_actionable_id, now();

END IF;





------------------------------------------------------------------

-- Create Step 3 (must be Open initially due to trigger)

------------------------------------------------------------------

INSERT INTO public.actionables_steps (

    ref_actionables_in_record_id,

    

    ref_users_in_record_id_owner,

    step_no,

    status,

    step_metadata

)

VALUES (

    v_actionable_id,

    

    v_ref_users_in_record_id_customer,

    3,

    'Open',

    p_step_3_json

)

RETURNING

    in_record_id,

    ref_users_in_record_id_owner

INTO

    v_step_3_id,

    v_step_3_owner;



------------------------------------------------------------------

-- Update Step 3 status if REJECT

------------------------------------------------------------------

IF p_response = 'REJECT' THEN

    UPDATE public.actionables_steps

    SET status = 'Discard'

    WHERE in_record_id = v_step_3_id;

END IF;

------------------------------------------------------------------

-- Complete Step 2

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    status = 'Complete',

    delivery_decision = initcap(lower(p_response)),

    ref_users_in_record_id_completed_by = v_created_by,

    step_metadata = p_json

WHERE in_record_id = p_actionable_step_id;



------------------------------------------------------------------

-- Resolve Step 2 Assigned Request Owner

------------------------------------------------------------------

SELECT

    ast.ref_requests_in_record_id_assigned_to

INTO

    v_step_2_request_id

FROM public.actionables_steps ast

WHERE ast.in_record_id = p_actionable_step_id;



IF v_step_2_request_id IS NOT NULL THEN



    SELECT r.owner

    INTO v_step_2_request_owner

    FROM public.requests r

    WHERE r.in_record_id = v_step_2_request_id;



END IF;



------------------------------------------------------------------

-- Build Step 3 Completion JSON

------------------------------------------------------------------

v_step_3_complete_json :=

jsonb_build_object(

    'metadata',

    jsonb_build_object(

        'reason', p_json -> 'metadata' ->> 'reason',

        'reason_customer', p_json -> 'metadata' ->> 'reason_consumer',

        'response_customer', p_json -> 'metadata' ->> 'response_consumer'

    ),

    'draftedData',

    '{}'::jsonb

);

------------------------------------------------------------------

-- Auto Complete Step 3

------------------------------------------------------------------

IF p_response = 'APPROVE'

   AND v_step_2_request_owner IS NOT NULL

   AND v_step_2_request_owner = v_step_3_owner

THEN



    UPDATE public.actionables_steps

    SET

        status = 'Complete',

        delivery_decision = initcap(lower(p_response)),

		step_metadata = v_step_3_complete_json,

        ref_users_in_record_id_completed_by = v_created_by

        

    WHERE in_record_id = v_step_3_id

      AND status = 'Open';



END IF;



------------------------------------------------------------------

-- Return

------------------------------------------------------------------

RETURN QUERY

SELECT

    v_actionable_id,

    p_actionable_step_id,

    v_step_3_id,

    p_request_id,

    CASE

        WHEN p_response = 'APPROVE'

            THEN 'STEP_2_COMPLETED_APPROVED'

        ELSE

            'STEP_2_COMPLETED_REJECTED'

    END;



END;

$function$