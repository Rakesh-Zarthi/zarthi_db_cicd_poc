CREATE OR REPLACE FUNCTION public.fn_validate_attachment_requests_fk()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_node_master_table bigint;

BEGIN

    ---------------------------------------------------------

    -- 1∩╕ÅΓâú Node MUST exist and be an Attachment node

    ---------------------------------------------------------

    SELECT n.ref_master_table_in_record_id

    INTO v_node_master_table

    FROM public.master_node n

    WHERE n.in_record_id = NEW.ref_master_node_in_record_id

      AND n.node_data_type = 'Attachment';



    IF v_node_master_table IS NULL THEN

        RAISE EXCEPTION

            'Node % is not a valid Attachment node',

            NEW.ref_master_node_in_record_id

            USING ERRCODE = '23503';

    END IF;



    ---------------------------------------------------------

    -- 2∩╕ÅΓâú Draft attachment allowed (no master key yet)

    ---------------------------------------------------------

    IF NEW.ref_master_key_in_record_id IS NULL THEN

        RETURN NEW;

    END IF;



    ---------------------------------------------------------

    -- 3∩╕ÅΓâú Master key MUST exist AND belong to SAME master table

    ---------------------------------------------------------

    IF NOT EXISTS (

        SELECT 1

        FROM public.master_key mk

        WHERE mk.in_record_id = NEW.ref_master_key_in_record_id

          AND mk.in_ref_master_table = v_node_master_table

    ) THEN

        RAISE EXCEPTION

            'Invalid master_key % for attachment node % (table mismatch)',

            NEW.ref_master_key_in_record_id,

            NEW.ref_master_node_in_record_id

            USING ERRCODE = '23503';

    END IF;



    ---------------------------------------------------------

    -- Γ£à All validations passed

    ---------------------------------------------------------

    RETURN NEW;

END;

$function$