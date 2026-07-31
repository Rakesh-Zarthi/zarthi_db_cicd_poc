CREATE OR REPLACE FUNCTION public.trg_apply_owner_sku_access()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    RAISE NOTICE '≡ƒöÑ trg_apply_owner_sku_access fired for row %', NEW.in_record_id;

    RETURN NEW;

END;

$function$