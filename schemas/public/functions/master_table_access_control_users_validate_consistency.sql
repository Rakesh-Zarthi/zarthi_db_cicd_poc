CREATE OR REPLACE FUNCTION public.master_table_access_control_users_validate_consistency()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_valid boolean;

BEGIN



    ----------------------------------------------------------------

    -- Rule 1: Root allowed ONLY for table 34

    ----------------------------------------------------------------

    IF NEW.is_root = TRUE

       AND NEW.ref_master_table_in_record_id_to <> 34 THEN



        RAISE EXCEPTION

        USING MESSAGE = format(

            'is_root can only be TRUE when ref_master_table_in_record_id_to = 34. Got %s',

            NEW.ref_master_table_in_record_id_to

        );



    END IF;





    ----------------------------------------------------------------

    -- Rule 2: Non-root must have node reference

    ----------------------------------------------------------------

    IF NEW.is_root = FALSE

       AND NEW.ref_master_node_in_record_id_from IS NULL THEN



        RAISE EXCEPTION

        USING MESSAGE =

            'ref_master_node_in_record_id_from is required when is_root = FALSE';



    END IF;





    ----------------------------------------------------------------

    -- Rule 3: Root entries do not require node validation

    ----------------------------------------------------------------

    IF NEW.is_root = TRUE THEN

        RETURN NEW;

    END IF;





    ----------------------------------------------------------------

    -- Rule 4: Validate node -> connected table mapping

    --

    -- ACL.ref_master_node_in_record_id_from

    --     = master_node.in_record_id

    --

    -- ACL.ref_master_table_in_record_id_to

    --     = master_node.ref_master_table_in_record_id_connected

    --

    -- master_node.ref_master_table_in_record_id_connected

    --     must not be NULL

    ----------------------------------------------------------------

    SELECT EXISTS (

        SELECT 1

        FROM master_node mn

        WHERE mn.in_record_id = NEW.ref_master_node_in_record_id_from

          AND mn.ref_master_table_in_record_id_connected IS NOT NULL

          AND mn.ref_master_table_in_record_id_connected =

              NEW.ref_master_table_in_record_id_to

    )

    INTO v_valid;





    ----------------------------------------------------------------

    -- Rule 5: Throw error if mapping invalid

    ----------------------------------------------------------------

    IF NOT v_valid THEN



        RAISE EXCEPTION

        USING MESSAGE = format(

            'Invalid ACL configuration: node %s is not connected to table %s',

            NEW.ref_master_node_in_record_id_from,

            NEW.ref_master_table_in_record_id_to

        );



    END IF;





    ----------------------------------------------------------------

    -- All validations passed

    ----------------------------------------------------------------

    RETURN NEW;



END;

$function$