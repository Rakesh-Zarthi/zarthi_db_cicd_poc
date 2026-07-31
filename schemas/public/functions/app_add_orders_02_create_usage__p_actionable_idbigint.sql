CREATE OR REPLACE FUNCTION public.app_add_orders_02_create_usage(p_actionable_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$

	

	DECLARE

	

	    ------------------------------------------------------------------

	    -- Actionable

	    ------------------------------------------------------------------

	    v_request_id                            bigint;

	    v_step_metadata                         jsonb;

	v_task_name     text;

	v_description   text;

	v_has_microservice boolean;

	v_has_hours boolean;

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

	    v_item                                  jsonb;

	

	

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

	-- Detect available data

	------------------------------------------------------------------

	v_has_microservice :=

	    v_step_metadata -> 'metadata' -> 'microservice' IS NOT NULL

	    AND jsonb_typeof(v_step_metadata -> 'metadata' -> 'microservice') = 'array'

	    AND jsonb_array_length(v_step_metadata -> 'metadata' -> 'microservice') > 0;

	

	v_has_hours :=

	    v_step_metadata -> 'metadata' -> 'hours' IS NOT NULL

	    AND jsonb_typeof(v_step_metadata -> 'metadata' -> 'hours') = 'array'

	    AND jsonb_array_length(v_step_metadata -> 'metadata' -> 'hours') > 0;

	

	IF NOT v_has_microservice

	   AND NOT v_has_hours

	THEN

	    RAISE EXCEPTION

	        '[CREATE_USAGE][METADATA_VALIDATE][ERROR] At least one of metadata.microservice or metadata.hours must contain data';

	END IF;

	

	------------------------------------------------------------------

	-- Resolve Microservice Metadata

	------------------------------------------------------------------

	IF v_has_microservice THEN

	

	FOR v_item IN

	    SELECT value

	    FROM jsonb_array_elements(

	        v_step_metadata -> 'metadata' -> 'microservice'

	    )

	LOOP

		

		IF COALESCE(trim(v_item ->> 'quantity'), '') = '' THEN

	    RAISE EXCEPTION

	        '[CREATE_USAGE][METADATA_VALIDATE][ERROR] quantity is mandatory';

	END IF;

	

	IF NOT ((v_item ->> 'quantity') ~ '^[0-9]+(\.[0-9]+)?$') THEN

	    RAISE EXCEPTION

	        '[CREATE_USAGE][METADATA_VALIDATE][ERROR] quantity must be numeric';

	END IF;

	

	

	    v_quantity :=

	        (v_item ->> 'quantity')::numeric;

	

	IF COALESCE(trim(v_item ->> 'msId'), '') = '' THEN

	    RAISE EXCEPTION

	        '[CREATE_USAGE][METADATA_VALIDATE][ERROR] msId is mandatory';

	END IF;

	

	IF NOT ((v_item ->> 'msId') ~ '^[0-9]+$') THEN

	    RAISE EXCEPTION

	        '[CREATE_USAGE][METADATA_VALIDATE][ERROR] msId must be numeric';

	END IF;

	

	    v_ref_services_sku_in_record_id :=

	        (v_item ->> 'msId')::bigint;

	

	

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

	    /*SELECT ss.price_in_inr

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

			NULL

	    )::public.create_usage_records_for_roles_input;

	

		------------------------------------------------------------------

		-- Create Usage Record

		------------------------------------------------------------------

		IF NOT public.app_create_usage_records_for_roles(

		    v_usage_input

		) THEN

		    RETURN FALSE;

		END IF;

		

		END LOOP;

	END IF;

	------------------------------------------------------------------

	-- Resolve Hours Metadata

	------------------------------------------------------------------

	IF v_has_hours THEN

	

	    IF jsonb_typeof(

	        v_step_metadata -> 'metadata' -> 'hours'

	    ) <> 'array'

	    THEN

	        RAISE EXCEPTION

	            '[CREATE_USAGE][METADATA_VALIDATE][ERROR] metadata.hours must be array';

	    END IF;

	

	    IF jsonb_array_length(

	        v_step_metadata -> 'metadata' -> 'hours'

	    ) = 0

	    THEN

	        RAISE EXCEPTION

	            '[CREATE_USAGE][METADATA_VALIDATE][ERROR] metadata.hours cannot be empty';

	    END IF;

	

	    FOR v_item IN

	        SELECT value

	        FROM jsonb_array_elements(

	            v_step_metadata -> 'metadata' -> 'hours'

	        )

	    LOOP

	

	        --------------------------------------------------------------

	        -- Quantity

	        --------------------------------------------------------------

	        IF COALESCE(trim(v_item ->> 'quantity'), '') = '' THEN

	            RAISE EXCEPTION

	                '[CREATE_USAGE][METADATA_VALIDATE][ERROR] quantity is mandatory';

	        END IF;

	

	        IF NOT ((v_item ->> 'quantity') ~ '^[0-9]+(\.[0-9]+)?$') THEN

	            RAISE EXCEPTION

	                '[CREATE_USAGE][METADATA_VALIDATE][ERROR] quantity must be numeric';

	        END IF;

	

	        v_quantity :=

	            (v_item ->> 'quantity')::numeric;

	

	        IF v_quantity <= 0 THEN

	            RAISE EXCEPTION

	                '[CREATE_USAGE][METADATA_VALIDATE][ERROR] quantity must be greater than zero';

	        END IF;

	

	        --------------------------------------------------------------

	        -- Task Name

	        --------------------------------------------------------------

	        v_task_name :=

	            trim(v_item ->> 'taskName');

	

	        IF COALESCE(v_task_name, '') = '' THEN

	            RAISE EXCEPTION

	                '[CREATE_USAGE][METADATA_VALIDATE][ERROR] taskName is mandatory';

	        END IF;

	

	        --------------------------------------------------------------

	        -- Description (optional)

	        --------------------------------------------------------------

	        v_description :=

	            v_item ->> 'description';

	

	        --------------------------------------------------------------

	        -- No SKU for Hours

	        --------------------------------------------------------------

	        v_ref_services_sku_in_record_id := NULL;

	

	--------------------------------------------------------------

	-- Resolve Unit Price from Owner's Internal CC

	--------------------------------------------------------------

	SELECT ucc.currency_calculator

	INTO v_unit_price

	FROM public.users_internal_cc ucc

	WHERE ucc.ref_users_in_record_id = v_ref_users_in_record_id_owner;

	

	IF v_unit_price IS NULL THEN

	    RAISE EXCEPTION

	        '[CREATE_USAGE][PRICE_RESOLVE][ERROR] owner_id=% reason=INTERNAL_CC_NOT_FOUND',

	        v_ref_users_in_record_id_owner;

	END IF;

	

	        --------------------------------------------------------------

	        -- Build Usage Input

	        --------------------------------------------------------------

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

	            v_task_name

	

	        )::public.create_usage_records_for_roles_input;

	

	        IF NOT public.app_create_usage_records_for_roles(

	            v_usage_input

	        ) THEN

	            RETURN FALSE;

	        END IF;

	

	    END LOOP;

	

	END IF;

		

		RETURN TRUE;

	

	END;

	$function$