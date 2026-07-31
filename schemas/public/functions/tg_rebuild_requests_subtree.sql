CREATE OR REPLACE FUNCTION public.tg_rebuild_requests_subtree()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- Rebuild subtree rooted at the updated request

    PERFORM public.rebuild_requests_subtree(NEW.ref_requests_record_id);

    RETURN NULL;

END;

$function$