CREATE OR REPLACE FUNCTION public.validate_requests_to_data_master_link()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_exists boolean;

BEGIN

    ------------------------------------------------------------------

    -- Enforce: master_key must belong to the declared master_table

    ------------------------------------------------------------------

    SELECT EXISTS (

        SELECT 1

        FROM public.master_key mk

        WHERE mk.in_record_id = NEW.ref_master_key_in_record_id

          AND mk.in_ref_master_table = NEW.ref_master_table_in_record_id

    )

    INTO v_exists;



    IF NOT v_exists THEN

        RAISE EXCEPTION

            'Invalid mapping: master_key % does not belong to master_table %',

            NEW.ref_master_key_in_record_id,

            NEW.ref_master_table_in_record_id

            USING ERRCODE = '23514';

    END IF;



    RETURN NEW;

END;

$function$