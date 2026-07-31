CREATE OR REPLACE FUNCTION public.app_billing_roles_sign_off_step_2_complete_v_0_0_1(p_actionable_step_id bigint, p_request_id bigint, p_json jsonb, p_step_3_json jsonb, p_response text)
 RETURNS TABLE(actionable_id bigint, step_2_id bigint, step_3_id bigint, request_id bigint, workflow_state text)
 LANGUAGE plpgsql
AS $function$



DECLARE



------------------------------------------------------------------

-- Session

------------------------------------------------------------------

v_user_uuid uuid;

v_created_by bigint;



------------------------------------------------------------------

-- Step

------------------------------------------------------------------

v_actionable_id bigint;

v_step_status text;

v_request_subject bigint;



------------------------------------------------------------------

-- Customer Resolution

------------------------------------------------------------------

v_bill_to text;

v_ref_users_in_record_id_customer bigint;



------------------------------------------------------------------

-- Step 3

------------------------------------------------------------------

v_step_3_id bigint;

------------------------------------------------------------------

-- Auto Complete Logic

------------------------------------------------------------------

v_step_2_request_id bigint;

v_step_2_request_owner bigint;

v_step_3_owner bigint;

v_step_3_complete_json jsonb;



BEGIN



------------------------------------------------------------------

-- Mandatory Validation

------------------------------------------------------------------

IF p_actionable_step_id IS NULL THEN

    RAISE EXCEPTION 'actionable_step_id is mandatory';

END IF;



IF p_request_id IS NULL THEN

    RAISE EXCEPTION 'request_id is mandatory';

END IF;



IF p_json IS NULL THEN

    RAISE EXCEPTION 'json is mandatory';

END IF;



IF COALESCE(trim(p_response), '') = '' THEN

    RAISE EXCEPTION 'response is mandatory';

END IF;



------------------------------------------------------------------

-- Validate Response

------------------------------------------------------------------

IF p_response NOT IN (

    'Delivered',

    'Not Delivered'

)

THEN

    RAISE EXCEPTION

        'response must be Delivered or Not Delivered';

END IF;



------------------------------------------------------------------

-- Resolve Session User

------------------------------------------------------------------

v_user_uuid :=

    current_setting(

        'app.CURRENT_USER_ID',

        true

    )::uuid;



SELECT u.in_record_id

INTO v_created_by

FROM public.users u

WHERE u.user_id = v_user_uuid;



IF v_created_by IS NULL THEN

    RAISE EXCEPTION

        'Unable to resolve session user';

END IF;



------------------------------------------------------------------

-- Resolve Step 2

------------------------------------------------------------------

SELECT

    ast.ref_actionables_in_record_id,

    ast.status,

    a.request_subject

INTO

    v_actionable_id,

    v_step_status,

    v_request_subject

FROM public.actionables_steps ast

INNER JOIN public.actionables a

    ON a.in_record_id = ast.ref_actionables_in_record_id

WHERE ast.in_record_id = p_actionable_step_id

  AND ast.step_no = 2;



IF v_actionable_id IS NULL THEN

    RAISE EXCEPTION

        'Invalid Step 2';

END IF;



IF v_request_subject <> p_request_id THEN

    RAISE EXCEPTION

        'Step does not belong to supplied request';

END IF;



IF v_step_status <> 'Open' THEN

    RAISE EXCEPTION

        'Step 2 must be Open';

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

    RAISE EXCEPTION

        'Step 3 already exists';

END IF;



------------------------------------------------------------------

-- Update Actionable Metadata

------------------------------------------------------------------

UPDATE public.actionables

SET action_metadata = p_json

WHERE in_record_id = v_actionable_id;





------------------------------------------------------------------

-- Resolve Bill To

------------------------------------------------------------------

SELECT sku_roles.bill_to

INTO v_bill_to

FROM public.requests_sku_roles rsr

INNER JOIN public.services_sku_roles sku_roles

    ON sku_roles.in_record_id = rsr.ref_services_sku_roles_in_record_id

WHERE rsr.ref_requests_in_record_id = p_request_id;



IF v_bill_to IS NULL THEN

    RAISE EXCEPTION

        'Bill To configuration not found for request %',

        p_request_id;

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

WHERE rsr.ref_requests_in_record_id = p_request_id;



IF v_ref_users_in_record_id_customer IS NULL THEN

    RAISE EXCEPTION

        'Unable to resolve customer owner for request %',

        p_request_id;

END IF;



------------------------------------------------------------------

-- Create Step 3

------------------------------------------------------------------

INSERT INTO public.actionables_steps (

    ref_actionables_in_record_id,

    step_no,

    status,

    ref_users_in_record_id_owner,

    step_metadata

)

VALUES (

    v_actionable_id,

    3,

    'Open',

    v_ref_users_in_record_id_customer,

    CASE

        WHEN p_response = 'Delivered'

            THEN p_step_3_json

        ELSE

            NULL

    END

)

RETURNING

    in_record_id,

    ref_users_in_record_id_owner

INTO

    v_step_3_id,

    v_step_3_owner;



------------------------------------------------------------------

-- Handle Not Delivered

------------------------------------------------------------------

IF p_response = 'Not Delivered' THEN



    UPDATE public.actionables_steps

    SET status = 'Discard'

    WHERE in_record_id = v_step_3_id;



END IF;

------------------------------------------------------------------

-- Complete Step 2

------------------------------------------------------------------

------------------------------------------------------------------

-- Complete Step 2

------------------------------------------------------------------

UPDATE public.actionables_steps

SET

    status = 'Complete',

    delivery_decision = p_response,

    step_metadata = p_json,

    ref_users_in_record_id_completed_by = v_created_by

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

        'response',

            p_json -> 'metadata' ->> 'response',



        'response_customer',

            p_json -> 'metadata' ->> 'response_consumer',



        'serviceRating_customer',

            (p_json -> 'metadata' ->> 'serviceRating_consumer')::integer,



        'specialistRating_customer',

            (p_json -> 'metadata' ->> 'specialistRating_consumer')::integer

    ),

    'draftedData',

    '{}'::jsonb

);

------------------------------------------------------------------

-- Auto Complete Step 3

------------------------------------------------------------------

IF p_response = 'Delivered'

   AND v_step_2_request_owner IS NOT NULL

   AND v_step_2_request_owner = v_step_3_owner

THEN



    UPDATE public.actionables_steps

    SET

        status = 'Complete',

        delivery_decision = p_response,

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

    'STEP_2_COMPLETE'::text;



END;

$function$