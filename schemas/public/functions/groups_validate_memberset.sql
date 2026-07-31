CREATE OR REPLACE FUNCTION public.groups_validate_memberset()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_group_id bigint;

BEGIN

    v_group_id :=

        COALESCE(NEW.ref_groups_in_record_id,

                 OLD.ref_groups_in_record_id);



    PERFORM public.groups_validate_memberset_core(v_group_id);



    RETURN NULL;

END;

$function$