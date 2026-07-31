CREATE OR REPLACE FUNCTION public.automation_set_node_sequence()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_next_seq int;

BEGIN

    -- 1) Respect user-supplied sequence

    IF NEW.node_sequence_number IS NOT NULL THEN

        RETURN NEW;

    END IF;



    -- 2) Must belong to a form

    IF NEW.ref_master_table_in_record_id IS NULL THEN

        RAISE EXCEPTION 'ref_master_table_in_record_id cannot be NULL when inserting a node.';

    END IF;



    -- 3) Compute next available sequence scoped to the form

    SELECT COALESCE(MAX(node_sequence_number), 0) + 1

    INTO v_next_seq

    FROM public.master_node

    WHERE ref_master_table_in_record_id = NEW.ref_master_table_in_record_id;



    NEW.node_sequence_number := v_next_seq;

    RETURN NEW;

END;

$function$