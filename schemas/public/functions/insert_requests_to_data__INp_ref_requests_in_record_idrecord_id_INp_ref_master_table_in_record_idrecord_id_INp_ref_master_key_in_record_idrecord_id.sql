CREATE OR REPLACE PROCEDURE public.insert_requests_to_data(IN p_ref_requests_in_record_id record_id, IN p_ref_master_table_in_record_id record_id, IN p_ref_master_key_in_record_id record_id)
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

    VALUES (

        p_ref_requests_in_record_id,

        p_ref_master_table_in_record_id,

        p_ref_master_key_in_record_id

    )

    ON CONFLICT (

        ref_requests_in_record_id,

        ref_master_table_in_record_id,

        ref_master_key_in_record_id

    )

    DO NOTHING;



    GET DIAGNOSTICS v_row_count = ROW_COUNT;



    IF v_row_count = 0 THEN

        RAISE NOTICE 'Data already exists in requests_to_data';

    ELSE

        RAISE NOTICE 'Data inserted successfully';

    END IF;



END;

$procedure$