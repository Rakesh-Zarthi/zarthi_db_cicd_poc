CREATE OR REPLACE PROCEDURE public.insert_requests_to_data(IN p_ref_requests record_id[], IN p_ref_master_tables record_id[], IN p_ref_master_keys record_id[])
 LANGUAGE plpgsql
AS $procedure$

DECLARE

    v_row_count INTEGER;

BEGIN

    INSERT INTO public.requests_to_data (

        ref_requests_in_record_id,

        ref_master_table_in_record_id,

        ref_master_key_in_record_id

    )

    SELECT *

    FROM unnest(

        p_ref_requests,

        p_ref_master_tables,

        p_ref_master_keys

    )

    ON CONFLICT (

        ref_requests_in_record_id,

        ref_master_table_in_record_id,

        ref_master_key_in_record_id

    )

    DO NOTHING;



    GET DIAGNOSTICS v_row_count = ROW_COUNT;



    RAISE NOTICE '% row(s) inserted successfully.', v_row_count;

END;

$procedure$