CREATE OR REPLACE FUNCTION public.fn_validate_requests_owner_assignment()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_owner_exists BOOLEAN;

    v_count_eligible INT;

    v_skipped INT;

BEGIN

    ----------------------------------------------------------------------

    -- 1) Validate NEW.owner exists (only when provided)

    ----------------------------------------------------------------------

    IF NEW.owner IS NOT NULL THEN

        SELECT EXISTS (

            SELECT 1 

            FROM public.users u

            WHERE u.in_record_id = NEW.owner

        )

        INTO v_owner_exists;



        IF NOT v_owner_exists THEN

            RAISE EXCEPTION 

                'Γ¥î Invalid owner (ID: %) ΓÇö no matching user found for request "%".',

                NEW.owner, NEW.in_record_name;

        END IF;

    END IF;





    ----------------------------------------------------------------------

    -- 2) Run validations on INSERT OR when owner changes (non-SKU checks)

    ----------------------------------------------------------------------

    IF TG_OP = 'INSERT'

       OR (TG_OP = 'UPDATE' AND NEW.owner IS DISTINCT FROM OLD.owner)

    THEN

        -- continue checks

    ELSE

        RETURN NEW;

    END IF;





    ----------------------------------------------------------------------

    -- 3) MODULE = 'Services' ΓÇö ONLY non-SKU checks here.

    -- Note: SKU-level 'forced_affinity = Yes' checks are handled in

    -- fn_validate_sku_forced_affinity (requests_services trigger).

    ----------------------------------------------------------------------

    IF NEW.module = 'Services' THEN



        ------------------------------------------------------------------

        -- 3A: If owner provided, you may still want to run eligibility checks.

        --      (This block runs only when NEW.owner is NOT NULL)

        ------------------------------------------------------------------

        IF NEW.owner IS NOT NULL THEN

            SELECT COUNT(*)

            INTO v_count_eligible

            FROM public.requests_services rs

            JOIN public.services_sku_onboarding ps

                  ON ps.ref_services_sku = rs.ref_services_sku

                 AND ps.sarthi_name     = NEW.owner

            WHERE rs.ref_requests_record_id = NEW.in_record_id

              -- Note: we intentionally do not filter by forced_affinity here;

              -- onboarding check can be applied to all SKUs or tailored elsewhere.

              AND ps.status IN ('Active','Dormant')

              AND ps.competence_level IN ('Apprentice','Practioner','Professional');



            IF v_count_eligible = 0 THEN

                RAISE EXCEPTION 

                    'Γ¥î Owner % lacks eligibility for required SKU(s).',

                    NEW.owner;

            END IF;

        END IF;



    END IF; -- END module = Services





----------------------------------------------------------------------

-- 3B) MODULE = 'Roles'

----------------------------------------------------------------------

IF NEW.module = 'Roles' THEN



    ------------------------------------------------------------------

    -- Validate owner eligibility for Roles

    ------------------------------------------------------------------

    IF NEW.owner IS NOT NULL THEN



        SELECT COUNT(*)

        INTO v_count_eligible

        FROM public.requests_sku_roles rsr

        JOIN public.roles_onboarding ro

              ON rsr.ref_services_sku_roles_in_record_id = ro.ref_services_sku_roles_in_record_id_role_name           

             AND ro.ref_users_in_record_id = NEW.owner

        WHERE rsr.ref_requests_in_record_id = NEW.in_record_id

          AND ro.status IN ('Active')

          AND ro.competence_level IN (

                'Apprentice',

                'Practioner',

                'Professional','Expert'

          );



        IF v_count_eligible = 0 THEN

            RAISE EXCEPTION

                'Γ¥î Owner % lacks eligibility for required Role(s).',

                NEW.owner;

        END IF;



    END IF;



END IF; -- END module = Roles





    ----------------------------------------------------------------------

    -- 4) FULL TREE CASCADE (Upward + Downward) for actionable owner updates

    ----------------------------------------------------------------------

    WITH RECURSIVE



    up_tree AS (

        SELECT OLD.in_record_id AS req_id

        UNION ALL

        SELECT rs.immediate_parent

        FROM up_tree ut

        JOIN public.requests_services rs

              ON rs.ref_requests_record_id = ut.req_id

        WHERE rs.immediate_parent IS NOT NULL

          AND rs.immediate_parent <> ut.req_id

    ),



    down_tree AS (

        SELECT OLD.in_record_id AS req_id

        UNION ALL

        SELECT r2.in_record_id

        FROM down_tree dt

        JOIN public.requests_services rs

              ON rs.immediate_parent = dt.req_id

        JOIN public.requests r2

              ON r2.in_record_id = rs.ref_requests_record_id

        WHERE r2.in_record_id <> dt.req_id

    ),



    full_tree AS (

        SELECT req_id FROM up_tree

        UNION

        SELECT req_id FROM down_tree

    ),



    non_open_actionables AS (

        SELECT COUNT(*) AS cnt

        FROM public.actionables a

        WHERE a.request_subject IN (SELECT req_id FROM full_tree)

          AND a.actionable_owner IS NOT DISTINCT FROM OLD.owner

          AND a.actionable_status <> 'Open'

    ),



    updated AS (

        UPDATE public.actionables a

           SET actionable_owner = NEW.owner

         WHERE a.request_subject IN (SELECT req_id FROM full_tree)

           AND a.actionable_owner IS NOT DISTINCT FROM OLD.owner

           AND a.actionable_status = 'Open' AND a.actionables_assigned_to IS NULL 

         RETURNING a.in_record_id

    )



    SELECT cnt INTO v_skipped

    FROM non_open_actionables;





    ----------------------------------------------------------------------

    -- 5) Developer warning for skipped actionables

    ----------------------------------------------------------------------

    IF v_skipped > 0 THEN

        RAISE NOTICE

            'ΓÜá∩╕Å % non-open actionables left unchanged. Only OPEN items updated.',

            v_skipped;

    END IF;





    ----------------------------------------------------------------------

    -- 6) Final success notice

    ----------------------------------------------------------------------

    RAISE NOTICE 

        '≡ƒöä Owner cascade complete for Request %, owner changed % ΓåÆ %',

        OLD.in_record_id, OLD.owner, NEW.owner;



    RETURN NEW;

END;

$function$