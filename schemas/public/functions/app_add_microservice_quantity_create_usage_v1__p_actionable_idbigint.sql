CREATE OR REPLACE FUNCTION public.app_add_microservice_quantity_create_usage_v1(p_actionable_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$



DECLARE



    ------------------------------------------------------------------

    -- Actionable

    ------------------------------------------------------------------

    v_request_id                            bigint;

    v_step_metadata                         jsonb;



    ------------------------------------------------------------------

    -- Usage Input

    ------------------------------------------------------------------

    v_usage_input                           public.create_usage_records_for_roles_input;



    ------------------------------------------------------------------

    -- Usage Data

    ------------------------------------------------------------------

    v_quantity                              numeric;

    v_ref_services_sku_in_record_id         bigint;

    v_unit_price                            numeric;



    ------------------------------------------------------------------

    -- Request Hierarchy

    ------------------------------------------------------------------

    v_immediate_parent_request_id           bigint;

    v_root_parent_request_id               bigint;



    ------------------------------------------------------------------

    -- User Resolution (FK)

    ------------------------------------------------------------------

    v_ref_users_in_record_id_owner          bigint;

    v_ref_users_in_record_id_consumer       bigint;

    v_ref_users_in_record_id_customer       bigint;



    ------------------------------------------------------------------

    -- Billing Resolution

    ------------------------------------------------------------------

    v_bill_to                               text;





BEGIN



    ------------------------------------------------------------------

    -- Resolve Actionable

    -- Filter to step_no = 1 to avoid ambiguous multi-row join

    ------------------------------------------------------------------

    SELECT

        a.request_subject,

        ast.step_metadata

    INTO

        v_request_id,

        v_step_metadata

    FROM public.actionables a

    JOIN public.actionables_steps ast

        ON ast.ref_actionables_in_record_id = a.in_record_id

       AND ast.step_no = 1  -- ΓåÉ was missing; join returned multiple rows

    WHERE a.in_record_id = p_actionable_id;



    IF v_request_id IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][ACTIONABLE_RESOLVE][ERROR] actionable_id=% reason=NOT_FOUND',

            p_actionable_id;

    END IF;



    ------------------------------------------------------------------

    -- Resolve Request Hierarchy

    ------------------------------------------------------------------

    SELECT

        rsr.immediate_parent,

        rsr.root_parent

    INTO

        v_immediate_parent_request_id,

        v_root_parent_request_id

    FROM public.requests_sku_roles rsr

    WHERE rsr.ref_requests_in_record_id = v_request_id;



    IF v_immediate_parent_request_id IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][HIERARCHY_RESOLVE][ERROR] request_id=% reason=IMMEDIATE_PARENT_NOT_FOUND',

            v_request_id;

    END IF;



    IF v_root_parent_request_id IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][HIERARCHY_RESOLVE][ERROR] request_id=% reason=ROOT_PARENT_NOT_FOUND',

            v_request_id;

    END IF;



------------------------------------------------------------------

-- Resolve Metadata

------------------------------------------------------------------

v_quantity :=

    COALESCE(

        (v_step_metadata -> 'metadata' ->> 'quantity')::numeric,

        0

    );



v_ref_services_sku_in_record_id :=

    (v_step_metadata -> 'metadata' ->> 'msId')::bigint;





    ------------------------------------------------------------------

    -- Validate Metadata

    ------------------------------------------------------------------

    IF v_quantity <= 0 THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][METADATA_VALIDATE][ERROR] actionable_id=% reason=QUANTITY_MISSING_OR_ZERO',

            p_actionable_id;

    END IF;



    IF v_ref_services_sku_in_record_id IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][METADATA_VALIDATE][ERROR] actionable_id=% reason=REF_SERVICES_SKU_MISSING',

            p_actionable_id;

    END IF;



    ------------------------------------------------------------------

    -- Resolve Unit Price

    ------------------------------------------------------------------

   /* SELECT ss.price_in_inr

    INTO v_unit_price

    FROM public.services_sku ss

    WHERE ss.in_record_id = v_ref_services_sku_in_record_id;



    IF v_unit_price IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][PRICE_RESOLVE][ERROR] ref_services_sku_in_record_id=% reason=PRICE_NOT_FOUND',

            v_ref_services_sku_in_record_id;

    END IF;*/



------------------------------------------------------------------

-- Resolve Unit Price

------------------------------------------------------------------

SELECT COALESCE(ss.price_in_inr, 0)

INTO v_unit_price

FROM public.services_sku ss

WHERE ss.in_record_id = v_ref_services_sku_in_record_id;



IF NOT FOUND THEN

    v_unit_price := 0;

END IF;

    ------------------------------------------------------------------

    -- Resolve OWNER

    -- Owner = Current Roles Request Owner

    ------------------------------------------------------------------

    SELECT r.owner

    INTO v_ref_users_in_record_id_owner

    FROM public.requests r

    WHERE r.in_record_id = v_request_id;



    IF v_ref_users_in_record_id_owner IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][OWNER_RESOLVE][ERROR] request_id=% reason=OWNER_NOT_FOUND',

            v_request_id;

    END IF;



    ------------------------------------------------------------------

    -- Resolve CONSUMER

    -- Consumer = Immediate Parent Request Owner

    ------------------------------------------------------------------

    SELECT r.owner

    INTO v_ref_users_in_record_id_consumer

    FROM public.requests r

    WHERE r.in_record_id = v_immediate_parent_request_id;



    IF v_ref_users_in_record_id_consumer IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][CONSUMER_RESOLVE][ERROR] immediate_parent_request_id=% reason=CONSUMER_NOT_FOUND',

            v_immediate_parent_request_id;

    END IF;



    ------------------------------------------------------------------

    -- Resolve Bill To Strategy

    ------------------------------------------------------------------

    SELECT sku_roles.bill_to

    INTO v_bill_to

    FROM public.requests_sku_roles rsr

    INNER JOIN public.services_sku_roles sku_roles

        ON sku_roles.in_record_id = rsr.ref_services_sku_roles_in_record_id

    WHERE rsr.ref_requests_in_record_id = v_request_id;



    IF v_bill_to IS NULL THEN

        RAISE EXCEPTION

            '[CREATE_USAGE][BILL_TO_RESOLVE][ERROR] request_id=% reason=BILL_TO_NOT_CONFIGURED',

            v_request_id;

    END IF;





    ------------------------------------------------------------------

    -- Resolve CUSTOMER + SKU Text + Practice

    -- Single query handles all three: avoids repeated joins

    ------------------------------------------------------------------

    SELECT

        CASE

            WHEN v_bill_to = 'Problem Owner'    THEN r_root.owner

            WHEN v_bill_to = 'Individual'       THEN u_roles_ind.in_record_id

            WHEN v_bill_to = 'Corporate Unit'   THEN u_roles_corp.in_record_id

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

        RAISE EXCEPTION

            '[CREATE_USAGE][CUSTOMER_RESOLVE][ERROR] request_id=% bill_to=% reason=CUSTOMER_NOT_RESOLVED',

            v_request_id,

            v_bill_to;

    END IF;





 



    ------------------------------------------------------------------

    -- Build Usage Input (all 16 fields)

    ------------------------------------------------------------------

    v_usage_input := ROW(



        v_request_id,

        v_unit_price,

        v_quantity,

        'Commercial Approval Pending',

        p_actionable_id,

        v_ref_users_in_record_id_consumer,

        v_ref_users_in_record_id_customer,

        v_ref_users_in_record_id_owner,

        v_ref_services_sku_in_record_id,

		null

    )::public.create_usage_records_for_roles_input;



    ------------------------------------------------------------------

    -- Create Usage Records

    -- BUG 1 FIX: PERFORM ΓåÆ RETURN

    -- PERFORM discarded the boolean return; always returned TRUE even when

    -- app_create_usage_records_for_roles failed and returned FALSE.

    ------------------------------------------------------------------

    RETURN public.app_create_usage_records_for_roles(v_usage_input);



    ------------------------------------------------------------------

    -- NO bare EXCEPTION block here.

    -- Errors now propagate naturally ΓÇö the caller raises its own exception

    -- on FALSE, and any unhandled error bubbles up with the real SQLERRM.

    -- BUG 3 FIX: was masking all failures with a silent RETURN FALSE.

    ------------------------------------------------------------------



END;

$function$