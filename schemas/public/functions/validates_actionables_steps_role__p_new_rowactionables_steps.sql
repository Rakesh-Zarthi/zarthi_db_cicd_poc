CREATE OR REPLACE FUNCTION public.validates_actionables_steps_role(p_new_row actionables_steps)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

v_request_id      bigint;

v_request_module  text;

v_bill_to         text;

v_json            jsonb;

v_role_user       bigint;

BEGIN

------------------------------------------------------------------

-- 1. Resolve actionable ΓåÆ request

------------------------------------------------------------------

SELECT r.in_record_id,

initcap(lower(trim(r.module)))

INTO v_request_id,

v_request_module

FROM public.actionables a

JOIN public.requests r

ON r.in_record_id = a.request_subject

WHERE a.in_record_id = p_new_row.ref_actionables_in_record_id;



IF NOT FOUND THEN

    RAISE EXCEPTION

        'Request not found for actionable %',

        p_new_row.ref_actionables_in_record_id

        USING ERRCODE = '23514';

END IF;



------------------------------------------------------------------

-- 2. Load workflow metadata

------------------------------------------------------------------

SELECT actionable_config

  INTO v_json

  FROM public.actionables_execution_metadata

 ORDER BY in_record_id DESC

 LIMIT 1;



IF v_json IS NULL THEN

    RAISE EXCEPTION

        'Actionables execution metadata not configured'

        USING ERRCODE = '23514';

END IF;



------------------------------------------------------------------

-- 3. Resolve Bill To

------------------------------------------------------------------

v_bill_to :=

    CASE v_request_module



        ------------------------------------------------------------------

        -- Staffing

        ------------------------------------------------------------------

        WHEN 'Staffing' THEN

            v_json -> 'Request'

                   -> 'Sub Request Type'

                   -> 'Staffing'

                   ->> 'Bill To'



        ------------------------------------------------------------------

        -- Services

        ------------------------------------------------------------------

        WHEN 'Services' THEN (

            SELECT sku.bill_to

            FROM public.requests_services rs

            JOIN public.services_sku sku

              ON rs.ref_services_sku = sku.in_record_id

            WHERE rs.ref_requests_record_id = v_request_id

        )



        ------------------------------------------------------------------

        -- Roles

        ------------------------------------------------------------------

        WHEN 'Roles' THEN (

            SELECT sku_roles.bill_to

            FROM public.requests_sku_roles rsr

            JOIN public.services_sku_roles sku_roles

              ON sku_roles.in_record_id =

                 rsr.ref_services_sku_roles_in_record_id

            WHERE rsr.ref_requests_in_record_id = v_request_id

        )



        ELSE NULL

    END;



IF v_bill_to IS NULL THEN

    RAISE EXCEPTION

        'Billing not configured for request % (module=%)',

        v_request_id,

        v_request_module

        USING ERRCODE = '23514';

END IF;



v_bill_to := initcap(lower(replace(v_bill_to,'owmer','owner')));



------------------------------------------------------------------

-- 4. Resolve Role_Based owner

------------------------------------------------------------------

SELECT

    CASE



        ------------------------------------------------------------------

        -- SERVICES

        ------------------------------------------------------------------

        WHEN v_request_module = 'Services'

         AND v_bill_to = 'Problem Owner'

        THEN r_root.owner



        WHEN v_request_module = 'Services'

         AND v_bill_to = 'Individual'

        THEN u_ind.in_record_id



        WHEN v_request_module = 'Services'

         AND v_bill_to = 'Corporate Unit'

        THEN u_corp.in_record_id



        ------------------------------------------------------------------

        -- STAFFING

        ------------------------------------------------------------------

        WHEN v_request_module = 'Staffing'

        THEN r_root.owner



        ------------------------------------------------------------------

        -- ROLES

        ------------------------------------------------------------------

        WHEN v_request_module = 'Roles'

         AND v_bill_to = 'Problem Owner'

        THEN r_root.owner



        WHEN v_request_module = 'Roles'

         AND v_bill_to = 'Individual'

        THEN u_roles_ind.in_record_id



        WHEN v_request_module = 'Roles'

         AND v_bill_to = 'Corporate Unit'

        THEN u_roles_corp.in_record_id



    END

INTO v_role_user

FROM public.requests r



------------------------------------------------------------------

-- Services joins

------------------------------------------------------------------

LEFT JOIN public.requests_services rs

       ON rs.ref_requests_record_id = r.in_record_id



LEFT JOIN public.services_sku sku

       ON sku.in_record_id = rs.ref_services_sku



LEFT JOIN public.users u_ind

       ON u_ind.in_record_id = sku.bill_to_individual_name



LEFT JOIN public.practices p

       ON p.in_record_id = sku.bill_to_corporate_unit



LEFT JOIN public.users u_corp

       ON u_corp.in_record_id = p.corporate_lead



------------------------------------------------------------------

-- Staffing joins

------------------------------------------------------------------

LEFT JOIN public.requests_staffing rf

       ON rf.ref_requests_record_id = r.in_record_id



------------------------------------------------------------------

-- Roles joins

------------------------------------------------------------------

LEFT JOIN public.requests_sku_roles rsr

       ON rsr.ref_requests_in_record_id = r.in_record_id



LEFT JOIN public.services_sku_roles sku_roles

       ON sku_roles.in_record_id =

          rsr.ref_services_sku_roles_in_record_id



LEFT JOIN public.users u_roles_ind

       ON u_roles_ind.in_record_id =

          sku_roles.ref_users_in_record_id_bill_to



LEFT JOIN public.practices p_roles

       ON p_roles.in_record_id =

          sku_roles.ref_practices_in_record_id_bill_to



LEFT JOIN public.users u_roles_corp

       ON u_roles_corp.in_record_id =

          p_roles.corporate_lead



------------------------------------------------------------------

-- Root parent resolution

------------------------------------------------------------------

LEFT JOIN public.requests r_root

       ON r_root.in_record_id = COALESCE(

            rs.root_parent,

            rf.root_parent,

            rsr.root_parent

       )



WHERE r.in_record_id = v_request_id;



------------------------------------------------------------------

-- 5. Enforce correctness

------------------------------------------------------------------

IF v_role_user IS NULL THEN

    RAISE EXCEPTION

        'Role owner could not be resolved (request %, module %, bill_to %)',

        v_request_id,

        v_request_module,

        v_bill_to

        USING ERRCODE = '23514';

END IF;



IF p_new_row.ref_users_in_record_id_owner <> v_role_user THEN

    RAISE EXCEPTION

        'Role_Based step must be owned by %, got %',

        v_role_user,

        p_new_row.ref_users_in_record_id_owner

        USING ERRCODE = '23514';

END IF;





END;

$function$