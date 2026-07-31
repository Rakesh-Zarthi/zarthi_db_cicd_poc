CREATE OR REPLACE FUNCTION public.timesheet_001_002_validate_time_range(p_from date_time, p_to date_time)
 RETURNS TABLE(start_ts timestamp without time zone, end_ts timestamp without time zone)
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_start timestamp;

    v_end   timestamp;

BEGIN

    v_start := (p_from).date_part + (p_from).time_part;

    v_end   := (p_to).date_part   + (p_to).time_part;



    IF v_end <= v_start THEN

        RAISE EXCEPTION 'Γ¥î to_date_time must be after from_date_time.';

    END IF;



    RETURN QUERY SELECT v_start, v_end;

END;

$function$