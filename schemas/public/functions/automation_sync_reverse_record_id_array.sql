CREATE OR REPLACE FUNCTION public.automation_sync_reverse_record_id_array()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_parent_table_id bigint;

    v_child_table_id bigint;



    v_parent_table text;

    v_child_table text;



    v_fk_column text;

    v_reverse_api text;

BEGIN

    -------------------------------------------------------------------

    -- 1∩╕ÅΓâú Identify parent/child table relationships

    -------------------------------------------------------------------

    v_child_table_id  := TG_ARGV[0]::bigint;      -- e.g. employee table ID

    v_parent_table_id := TG_ARGV[1]::bigint;      -- e.g. department table ID

    v_fk_column       := TG_ARGV[2];              -- e.g. department_id

    v_reverse_api     := TG_ARGV[3];              -- e.g. employee_list



    -------------------------------------------------------------------

    -- 2∩╕ÅΓâú Resolve table_api_name from master_table

    -------------------------------------------------------------------

    SELECT table_api_name INTO v_child_table

    FROM public.master_table WHERE in_record_id = v_child_table_id;



    SELECT table_api_name INTO v_parent_table

    FROM public.master_table WHERE in_record_id = v_parent_table_id;



    -------------------------------------------------------------------

    -- Γ¥ù Option 1: VIRTUAL reverse fields

    -- DO NOT update parent table; no SQL columns exist

    --

    -- Reverse lists are NOT stored physically.

    -- They are computed at query-time based on FK values.

    -------------------------------------------------------------------



    -- NO SQL UPDATE HERE

    -- NO reverse array persistence



    RETURN NEW;

END;

$function$