CREATE OR REPLACE FUNCTION public.trg_reconcile_access_onboarding()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    PERFORM public.zarthi_master_access_reconcile_cache_for_onboardings(

        ARRAY[NEW.in_record_id::bigint]

    );

    RETURN NEW;

END;

$function$