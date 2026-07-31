CREATE OR REPLACE FUNCTION public.groups_validations()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_root_parent    bigint;

    v_owner_status   text;

    v_owner_module   text;

    v_has_main_group boolean;

BEGIN

    ------------------------------------------------------------------

    -- COMMON CANONICAL VALIDATIONS (INSERT + UPDATE)

    ------------------------------------------------------------------



    IF NEW.group_type NOT IN ('Main Group', 'Sub Group') THEN

        RAISE EXCEPTION

            'Invalid group_type "%". Allowed values: Main Group, Sub Group.',

            NEW.group_type;

    END IF;



    IF NEW.channel NOT IN ('Teams', 'Email') THEN

        RAISE EXCEPTION

            'Invalid channel "%". Allowed values: Teams, Email.',

            NEW.channel;

    END IF;



    ------------------------------------------------------------------

    -- INSERT-ONLY VALIDATIONS

    ------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        ------------------------------------------------------------------

        -- 1∩╕ÅΓâú GROUP OWNER REQUEST MUST EXIST AND BE ACTIVE

        ------------------------------------------------------------------

        SELECT r.status

        INTO v_owner_status

        FROM public.requests r

        WHERE r.in_record_id = NEW.ref_requests_in_record_id_group_owner;



        IF v_owner_status IS NULL THEN

            RAISE EXCEPTION

                'Group creation denied. Owner request % does not exist.',

                NEW.ref_requests_in_record_id_group_owner;

        END IF;



        IF v_owner_status = 'Close' THEN

            RAISE EXCEPTION

                'Group creation denied. Owner request % is already "%".',

                NEW.ref_requests_in_record_id_group_owner,

                v_owner_status;

        END IF;



        ------------------------------------------------------------------

        -- 2∩╕ÅΓâú RESOLVE ROOT PROBLEM (CANONICAL TREE)

        ------------------------------------------------------------------

        SELECT rh.root_parent

        INTO v_root_parent

        FROM public.requests_hierarchy rh

        WHERE rh.request_id = NEW.ref_requests_in_record_id_group_owner;



        IF v_root_parent IS NULL THEN

            RAISE EXCEPTION

                'Group creation denied. Request % is not part of a valid hierarchy.',

                NEW.ref_requests_in_record_id_group_owner;

        END IF;



        ------------------------------------------------------------------

        -- 3∩╕ÅΓâú SUB GROUP REQUIRES EXISTING MAIN GROUP (SAME TREE)

        ------------------------------------------------------------------

        IF NEW.group_type = 'Sub Group' THEN

            SELECT EXISTS (

                SELECT 1

                FROM public.groups g

                JOIN public.requests_hierarchy rh2

                  ON rh2.request_id = g.ref_requests_in_record_id_group_owner

                WHERE rh2.root_parent = v_root_parent

                  AND g.group_type = 'Main Group'

            )

            INTO v_has_main_group;



            IF NOT v_has_main_group THEN

                RAISE EXCEPTION

                    'Sub Group creation denied. No Main Group exists for root request %.',

                    v_root_parent;

            END IF;

        END IF;



        ------------------------------------------------------------------

        -- 4∩╕ÅΓâú MAIN GROUP MUST BE ROOT PROBLEM

        ------------------------------------------------------------------

        IF NEW.group_type = 'Main Group' THEN

            IF NOT EXISTS (

                SELECT 1

                FROM public.requests_hierarchy rh

                WHERE rh.request_id = NEW.ref_requests_in_record_id_group_owner

                  AND rh.level = 1

                  AND rh.module = 'Problem'

            ) THEN

                RAISE EXCEPTION

                    'Main Group creation denied. Request % is not a root Problem.',

                    NEW.ref_requests_in_record_id_group_owner;

            END IF;

        END IF;



        ------------------------------------------------------------------

        -- 5∩╕ÅΓâú GROUP NAME MUST BE UNIQUE WITHIN TREE

        ------------------------------------------------------------------

        IF EXISTS (

            SELECT 1

            FROM public.groups g

            JOIN public.requests_hierarchy rh2

              ON rh2.request_id = g.ref_requests_in_record_id_group_owner

            WHERE rh2.root_parent = v_root_parent

              AND lower(trim(g.group_name)) =

                  lower(trim(NEW.group_name))

        ) THEN

            RAISE EXCEPTION

                'Group creation denied. Group name "%" already exists under root request %.',

                NEW.group_name,

                v_root_parent;

        END IF;



    END IF;



    ------------------------------------------------------------------

    -- UPDATE-ONLY VALIDATIONS (IMMUTABILITY)

    ------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN



        IF NEW.group_name IS DISTINCT FROM OLD.group_name THEN

            RAISE EXCEPTION

                'Update denied. group_name is immutable after creation.';

        END IF;



        IF NEW.ref_requests_in_record_id_group_owner

           IS DISTINCT FROM OLD.ref_requests_in_record_id_group_owner THEN

            RAISE EXCEPTION

                'Update denied. group owner request is immutable.';

        END IF;



        IF NEW.group_type IS DISTINCT FROM OLD.group_type THEN

            RAISE EXCEPTION

                'Update denied. group_type is immutable.';

        END IF;



     ------------------------------------------------------------------

     -- PREVENT REOPENING CLOSED GROUP

     ------------------------------------------------------------------

     IF OLD.status = 'Closed'

     AND NEW.status = 'Active' THEN

          RAISE EXCEPTION

                'Closed group cannot be reopened.';

     END IF;



        ------------------------------------------------------------------

        -- 6∩╕ÅΓâú PREVENT CLOSING GROUP IF OWNER PROBLEM REQUEST NOT CLOSED

        ------------------------------------------------------------------

        IF NEW.status IS DISTINCT FROM OLD.status

           AND NEW.status = 'Closed' THEN



            SELECT r.status, r.module

            INTO v_owner_status, v_owner_module

            FROM public.requests r

            WHERE r.in_record_id =

                  NEW.ref_requests_in_record_id_group_owner;



            IF v_owner_module = 'Problem'

               AND v_owner_status <> 'Close' THEN



                RAISE EXCEPTION

                    'Group cannot be closed. Owner Problem request % must be closed first. Current status: "%".',

                    NEW.ref_requests_in_record_id_group_owner,

                    v_owner_status;



            END IF;



        END IF;



    END IF;



    RETURN NEW;



END;

$function$