CREATE OR REPLACE FUNCTION public.timesheet_001_wrapper_validations()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_start_ts timestamp;

    v_end_ts   timestamp;

    v_bypass   BOOLEAN := FALSE;

BEGIN

    ------------------------------------------------------------------

    -- 001 Mandatory

    ------------------------------------------------------------------

    PERFORM public.timesheet_001_001_validate_mandatory(NEW);



    ------------------------------------------------------------------

    -- 002 Time validation

    ------------------------------------------------------------------

    SELECT start_ts, end_ts

    INTO v_start_ts, v_end_ts

    FROM public.timesheet_001_002_validate_time_range(

        NEW.from_date_time,

        NEW.to_date_time

    );



    ------------------------------------------------------------------

    -- 003 Backdate

    ------------------------------------------------------------------

    PERFORM public.timesheet_001_003_validate_backdate(

        TG_OP,

        NEW,

        CASE WHEN TG_OP = 'UPDATE' THEN OLD ELSE NULL END

    );



    ------------------------------------------------------------------

    -- 004 Status normalization

    ------------------------------------------------------------------

    NEW.status := public.timesheet_001_004_normalize_status(NEW.status);





    ------------------------------------------------------------------

    -- 007 Timesheet allowed by config

    ------------------------------------------------------------------

    PERFORM public.actionables_metadata_004_timesheet_config(NEW, TG_OP);



	------------------------------------------------------------------

	-- 008 Step owner validation

	------------------------------------------------------------------

	PERFORM public.timesheet_001_005_validate_professional(NEW);



    ------------------------------------------------------------------

    -- 009 Usage linkage validation

    ------------------------------------------------------------------

    PERFORM public.timesheet_001_006_validate_usage_link(NEW);





    ------------------------------------------------------------------

    -- FINAL RETURN

    ------------------------------------------------------------------

    RETURN NEW;

END;

$function$