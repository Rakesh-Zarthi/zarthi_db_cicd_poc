CREATE OR REPLACE FUNCTION public.attachment_fill_ref_master_key_from_node()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_master_key_id bigint;

BEGIN

    -- nothing to do if there's no node reference

    IF NEW.ref_master_node_in_record_id IS NULL THEN

        RETURN NEW;

    END IF;



    -- If user already provided ref_master_key_in_record_id, validate it matches the node's parent master

    IF NEW.ref_master_key_in_record_id IS NOT NULL THEN

        PERFORM 1

        FROM public.master_node mn

        WHERE mn.in_record_id = NEW.ref_master_node_in_record_id

          AND mn.ref_master_table_in_record_id = NEW.ref_master_key_in_record_id;

        IF FOUND THEN

            RETURN NEW; -- already correct

        ELSE

            RAISE EXCEPTION 'attachment_metadata: provided ref_master_key_in_record_id (%) does not match parent master for node %',

                NEW.ref_master_key_in_record_id, NEW.ref_master_node_in_record_id;

        END IF;

    END IF;



    -- Look up the parent master_table's in_record_id from master_node

    SELECT mn.ref_master_table_in_record_id

    INTO v_master_key_id

    FROM public.master_node mn

    WHERE mn.in_record_id = NEW.ref_master_node_in_record_id

    LIMIT 1;



    IF v_master_key_id IS NULL THEN

        RAISE EXCEPTION 'attachment_metadata: master_node % not found or has no ref_master_table_in_record_id',

            NEW.ref_master_node_in_record_id;

    END IF;



    NEW.ref_master_key_in_record_id := v_master_key_id;

    RETURN NEW;

END;

$function$