CREATE OR REPLACE FUNCTION public.actionables_metadata_004_timesheet_config(p_row timesheet, p_operation text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_actionable_name text;

    v_step_no         int;

    v_step_status     text;

    v_step_cfg        jsonb;

    v_allow_timesheet boolean;

    v_metadata        jsonb;

BEGIN

    ------------------------------------------------------------------

    -- 1) Mandatory: Step reference

    ------------------------------------------------------------------

    IF p_row.ref_actionables_steps_in_record_id IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Timesheet must be linked to an actionable step.';

    END IF;



    ------------------------------------------------------------------

    -- 2) Resolve actionable + step + status (strict)

    ------------------------------------------------------------------

    SELECT a.actionable_name,

           s.step_no,

           s.status

    INTO v_actionable_name,

         v_step_no,

         v_step_status

    FROM public.actionables_steps s

    JOIN public.actionables a

      ON a.in_record_id = s.ref_actionables_in_record_id

    WHERE s.in_record_id = p_row.ref_actionables_steps_in_record_id

      AND s.ref_actionables_in_record_id = p_row.ref_actionables_in_record_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Γ¥î Step does not exist or does not belong to actionable.';

    END IF;



    ------------------------------------------------------------------

    -- 3) Validate + normalize step status

    ------------------------------------------------------------------

    IF v_step_status IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Step status cannot be NULL for "%", step %.',

            v_actionable_name,

            v_step_no;

    END IF;



    v_step_status := initcap(lower(trim(v_step_status)));



-- Apply ONLY on INSERT

IF p_operation = 'INSERT' THEN

    IF v_step_status NOT IN ('Draft', 'Open') THEN

        RAISE EXCEPTION

            'Γ¥î Timesheet allowed only when step is Draft/Open (current=%).',

            v_step_status;

    END IF;

END IF;



    ------------------------------------------------------------------

    -- 4) Fetch metadata once

    ------------------------------------------------------------------

    v_metadata := public.actionables_metadata_001_get_metadata();



    IF v_metadata IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Metadata not configured.';

    END IF;



    ------------------------------------------------------------------

    -- 5) Resolve step config safely

    ------------------------------------------------------------------

    v_step_cfg :=

        v_metadata

        -> 'Request'

        -> 'Actionable'

        -> v_actionable_name

        -> 'Steps'

        -> v_step_no::text;



    IF v_step_cfg IS NULL OR jsonb_typeof(v_step_cfg) <> 'object' THEN

        RAISE EXCEPTION

            'Γ¥î Step config missing: Request ΓåÆ Actionable ΓåÆ % ΓåÆ Steps ΓåÆ %',

            v_actionable_name,

            v_step_no;

    END IF;



    ------------------------------------------------------------------

    -- 6) Allow Timesheet (implicit deny)

    ------------------------------------------------------------------

    v_allow_timesheet :=

        lower(trim(coalesce(v_step_cfg ->> 'Allow Timesheet','false'))) = 'true';



    ------------------------------------------------------------------

    -- 7) Explicit override (business rule)

    ------------------------------------------------------------------

    IF NOT v_allow_timesheet

       AND v_actionable_name IN ('Add Timesheet', 'Update Timesheet') THEN

        v_allow_timesheet := TRUE;

    END IF;



    ------------------------------------------------------------------

    -- 8) Final enforcement

    ------------------------------------------------------------------

    IF NOT v_allow_timesheet THEN

        RAISE EXCEPTION

            'Γ¥î Timesheet not allowed for "%", step %.',

            v_actionable_name,

            v_step_no;

    END IF;



END;

$function$