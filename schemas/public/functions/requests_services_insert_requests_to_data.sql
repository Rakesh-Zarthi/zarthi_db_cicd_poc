CREATE OR REPLACE FUNCTION public.requests_services_insert_requests_to_data()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

BEGIN

    -- Execute only for SKU 3112 or 3114

    IF NEW.ref_services_sku IN (3112, 3114,3113) THEN



        INSERT INTO public.requests_to_data

        (

            ref_requests_in_record_id,

            ref_master_table_in_record_id,

            ref_master_key_in_record_id

        )

        VALUES

        (

            NEW.ref_requests_record_id,

            6,

            NEW.immediate_parent

        )

        ON CONFLICT

        (

            ref_requests_in_record_id,

            ref_master_table_in_record_id,

            ref_master_key_in_record_id

        )

        DO NOTHING;



    END IF;



    RETURN NEW;

END;

$function$