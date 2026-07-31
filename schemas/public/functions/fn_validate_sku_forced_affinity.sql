CREATE OR REPLACE FUNCTION public.fn_validate_sku_forced_affinity()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_forced_affinity text;

    v_owner bigint;

BEGIN

    ----------------------------------------------------------------------

    -- 1) Fetch forced_affinity for the SKU being (inserted/updated)

    ----------------------------------------------------------------------

    SELECT s.forced_affinity

    INTO v_forced_affinity

    FROM public.services_sku s

    WHERE s.in_record_id = NEW.ref_services_sku;



    ----------------------------------------------------------------------

    -- 2) Fetch owner of the parent request (if parent exists)

    ----------------------------------------------------------------------

    SELECT r.owner

    INTO v_owner

    FROM public.requests r

    WHERE r.in_record_id = NEW.ref_requests_record_id;



    ----------------------------------------------------------------------

    -- 3) If SKU requires owner AND owner is null/empty ΓåÆ throw error

    --    (also handle empty string if owner is stored as text; your owner

    --     is record_id so NULL is the main concern)

    ----------------------------------------------------------------------

    IF v_forced_affinity = 'Yes' AND v_owner IS NULL THEN

        RAISE EXCEPTION

            'Γ¥î Owner is required because SKU % (used in request %) has forced_affinity = Yes.',

            NEW.ref_services_sku, NEW.ref_requests_record_id;

    END IF;



    RETURN NEW;

END;

$function$