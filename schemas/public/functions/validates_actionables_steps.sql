CREATE OR REPLACE FUNCTION public.validates_actionables_steps()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    -- Core context

    v_actionable_name      text;

    v_request_id           bigint;



    -- JSON

    v_cfg                  jsonb;

    v_actionable_cfg       jsonb;

    v_steps_cfg            jsonb;

    v_step_cfg             jsonb;



    -- Step

    v_step_no_txt          text;

    v_allowed_statuses     jsonb;

    v_step_type            text;

    v_step_owner_rule      text;



    -- Sequencing

    v_prev_status          text;

    v_next_json_step       int;

    v_loop_guard           int := 0;

    v_cursor_step          text;

BEGIN

    --------------------------------------------------------------------

    -- 1. Enforce 1-based steps

    --------------------------------------------------------------------

    IF NEW.step_no < 1 THEN

        RAISE EXCEPTION

            'step_no must start from 1 (got %)', NEW.step_no

            USING ERRCODE = '23514';

    END IF;



    v_step_no_txt := NEW.step_no::text;



    --------------------------------------------------------------------

    -- 2. Resolve actionable

    --------------------------------------------------------------------

    SELECT a.actionable_name,

           a.request_subject

    INTO v_actionable_name,

         v_request_id

    FROM public.actionables a

    WHERE a.in_record_id = NEW.ref_actionables_in_record_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Actionable % not found',

            NEW.ref_actionables_in_record_id

            USING ERRCODE = '23503';

    END IF;



    --------------------------------------------------------------------

    -- 3. Load latest execution metadata

    --------------------------------------------------------------------

    SELECT actionable_config

    INTO v_cfg

    FROM public.actionables_execution_metadata

    ORDER BY in_modified_time DESC NULLS LAST,

             in_added_time DESC NULLS LAST

    LIMIT 1;



    IF v_cfg IS NULL THEN

        RAISE EXCEPTION

            'Execution metadata JSON missing'

            USING ERRCODE = '23514';

    END IF;



    --------------------------------------------------------------------

    -- 4. Extract actionable config

    --------------------------------------------------------------------

    v_actionable_cfg := v_cfg #> ARRAY['Request','Actionable',v_actionable_name];



    IF v_actionable_cfg IS NULL THEN

        RAISE EXCEPTION

            'Actionable "%" not configured in JSON',

            v_actionable_name

            USING ERRCODE = '23514';

    END IF;



    v_steps_cfg := v_actionable_cfg -> 'Steps';



    IF v_steps_cfg IS NULL

       OR jsonb_typeof(v_steps_cfg) <> 'object' THEN

        RAISE EXCEPTION

            'Steps block missing or invalid for "%"',

            v_actionable_name

            USING ERRCODE = '23514';

    END IF;



    --------------------------------------------------------------------

    -- 5. Validate step exists

    --------------------------------------------------------------------

    v_step_cfg := v_steps_cfg -> v_step_no_txt;



    IF v_step_cfg IS NULL THEN

        RAISE EXCEPTION

            'Step % not defined in JSON for "%"',

            NEW.step_no, v_actionable_name

            USING ERRCODE = '23514';

    END IF;



    --------------------------------------------------------------------

    -- 5A. Planned / Open lifecycle rules

    --------------------------------------------------------------------

    -- Step 1 must be Planned on insert

    IF TG_OP = 'INSERT'

       AND NEW.step_no = 1

       AND NEW.status <> 'Planned' THEN

        RAISE EXCEPTION

            'Step 1 must be inserted with status = Planned (got %)',

            NEW.status

            USING ERRCODE = '23514';

    END IF;



    -- Steps > 1 can never be Planned

    IF NEW.step_no > 1

       AND NEW.status = 'Planned' THEN

        RAISE EXCEPTION

            'Step % cannot have status Planned',

            NEW.step_no

            USING ERRCODE = '23514';

    END IF;



    -- Steps > 1 must be Open on insert

    IF TG_OP = 'INSERT'

       AND NEW.step_no > 1

       AND NEW.status <> 'Open' THEN

        RAISE EXCEPTION

            'Step % must be inserted with status = Open (got %)',

            NEW.step_no, NEW.status

            USING ERRCODE = '23514';

    END IF;



    --------------------------------------------------------------------

    -- 6. Enforce sequential creation (no gaps)

    --------------------------------------------------------------------

    IF TG_OP = 'INSERT'

       AND NEW.step_no > 1 THEN

        IF NOT EXISTS (

            SELECT 1

            FROM public.actionables_steps

            WHERE ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

              AND step_no = NEW.step_no - 1

        ) THEN

            RAISE EXCEPTION

                'Cannot create step % ΓÇö step % must exist first',

                NEW.step_no, NEW.step_no - 1

                USING ERRCODE = '23514';

        END IF;

    END IF;



    --------------------------------------------------------------------

    -- 7. Status validation

    --------------------------------------------------------------------

    v_allowed_statuses := v_step_cfg -> 'Step Status';



    IF jsonb_typeof(v_allowed_statuses) <> 'array' THEN

        RAISE EXCEPTION

            'Invalid JSON: Step Status must be array for "%" step %',

            v_actionable_name, NEW.step_no

            USING ERRCODE = '23514';

    END IF;



    IF NOT (v_allowed_statuses ? NEW.status::text) THEN

        RAISE EXCEPTION

            'Status "%" not allowed for "%" step % (allowed=%)',

            NEW.status, v_actionable_name, NEW.step_no, v_allowed_statuses

            USING ERRCODE = '23514';

    END IF;



    --------------------------------------------------------------------

    -- 8. Backward completion enforcement

    --------------------------------------------------------------------

    IF NEW.status = 'Complete'

       AND NEW.step_no > 1 THEN

        SELECT status::text

        INTO v_prev_status

        FROM public.actionables_steps

        WHERE ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

          AND step_no = NEW.step_no - 1;



        IF v_prev_status IS DISTINCT FROM 'Complete' THEN

            RAISE EXCEPTION

                'Step % cannot complete until step % completes',

                NEW.step_no, NEW.step_no - 1

                USING ERRCODE = '23514';

        END IF;

    END IF;



    --------------------------------------------------------------------

    -- 8A. Forward existence enforcement (YOUR REQUIRED RULE)

    --------------------------------------------------------------------

    IF NEW.status = 'Complete' THEN

        v_next_json_step :=

            (v_steps_cfg -> v_step_no_txt ->> 'Next Step')::int;



        IF v_next_json_step IS NOT NULL THEN

            IF NOT EXISTS (

                SELECT 1

                FROM public.actionables_steps

                WHERE ref_actionables_in_record_id = NEW.ref_actionables_in_record_id

                  AND step_no = v_next_json_step

            ) THEN

                RAISE EXCEPTION

                    'Cannot complete Step % ΓÇö Step % must be created first',

                    NEW.step_no, v_next_json_step

                    USING ERRCODE = '23514';

            END IF;

        END IF;

    END IF;



    --------------------------------------------------------------------

    -- 9. Forward chain validation + loop detection

    --------------------------------------------------------------------

    v_cursor_step := v_step_no_txt;



    WHILE v_cursor_step IS NOT NULL LOOP

        v_loop_guard := v_loop_guard + 1;



        IF v_loop_guard > 50 THEN

            RAISE EXCEPTION

                'Loop detected in Next Step chain for "%"',

                v_actionable_name

                USING ERRCODE = '23514';

        END IF;



        v_next_json_step :=

            (v_steps_cfg -> v_cursor_step ->> 'Next Step')::int;



        EXIT WHEN v_next_json_step IS NULL;



        IF NOT (v_steps_cfg ? v_next_json_step::text) THEN

            RAISE EXCEPTION

                'Next Step % missing in JSON for "%"',

                v_next_json_step, v_actionable_name

                USING ERRCODE = '23514';

        END IF;



        v_cursor_step := v_next_json_step::text;

    END LOOP;



    --------------------------------------------------------------------

    -- 10. Step Type / Owner validation

    --------------------------------------------------------------------

    v_step_type := replace(v_step_cfg ->> 'Step Type',' ','_');

    v_step_owner_rule := v_step_cfg ->> 'Step Owner';



    IF v_step_type IS NULL OR v_step_owner_rule IS NULL THEN

        RAISE EXCEPTION

            'Step Type / Owner missing for "%", step %',

            v_actionable_name, NEW.step_no

            USING ERRCODE = '23514';

    END IF;



    --------------------------------------------------------------------

    -- 11. Delegate ownership logic

    --------------------------------------------------------------------

    IF v_step_type = 'Request_Based' THEN

        PERFORM public.validates_actionables_steps_requests(NEW, v_step_owner_rule);



      ELSIF v_step_type = 'User_Based' THEN



        IF v_actionable_name = 'Sign Off' THEN

            PERFORM public.validates_actionables_steps_role(NEW);

        ELSE

            PERFORM public.validates_actionables_steps_role_generic(NEW);

        END IF;



    ELSE

        RAISE EXCEPTION

            'Unsupported Step Type "%" for "%", step %',

            v_step_type, v_actionable_name, NEW.step_no

            USING ERRCODE = '23514';

    END IF;



	--------------------------------------------------------------------

	-- 12. Validate assigned user (centralized rule)

	--------------------------------------------------------------------

	PERFORM public.users_0034_validate_users_assignment(

	    NEW.ref_users_in_record_id_owner,

	    'step owner'

	);



    RETURN NEW;

END;

$function$