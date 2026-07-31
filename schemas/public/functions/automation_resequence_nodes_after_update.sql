CREATE OR REPLACE FUNCTION public.automation_resequence_nodes_after_update()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_fk bigint;

    v_old_seq int;

    v_new_seq int;

BEGIN

    -- a) Identify form FK

    v_fk := COALESCE(NEW.ref_master_table_in_record_id, OLD.ref_master_table_in_record_id);

    IF v_fk IS NULL THEN

        RETURN NEW;

    END IF;



    v_old_seq := OLD.node_sequence_number;

    v_new_seq := NEW.node_sequence_number;



    -- nothing to do

    IF v_old_seq = v_new_seq THEN

        RETURN NEW;

    END IF;



    -- prevent recursion if another resequence is ongoing in the same session

    IF current_setting('app.resequence_running', true) = 'on' THEN

        RETURN NEW;

    END IF;

    PERFORM set_config('app.resequence_running', 'on', false);



    -- lock per-form (stable)

    PERFORM pg_advisory_xact_lock(v_fk);



    -- shift siblings

    IF v_new_seq < v_old_seq THEN

        -- moved up: shift others down by +1 in [new, old)

        UPDATE public.master_node

        SET node_sequence_number = node_sequence_number + 1

        WHERE ref_master_table_in_record_id = v_fk

          AND node_sequence_number >= v_new_seq

          AND node_sequence_number < v_old_seq

          AND in_record_id <> NEW.in_record_id;

    ELSE

        -- moved down: shift others up by -1 in (old, new]

        UPDATE public.master_node

        SET node_sequence_number = node_sequence_number - 1

        WHERE ref_master_table_in_record_id = v_fk

          AND node_sequence_number <= v_new_seq

          AND node_sequence_number > v_old_seq

          AND in_record_id <> NEW.in_record_id;

    END IF;



    -- ensure the moved node gets the correct value

    UPDATE public.master_node

    SET node_sequence_number = v_new_seq

    WHERE in_record_id = NEW.in_record_id;



    PERFORM set_config('app.resequence_running', 'off', false);

    RETURN NEW;

END;

$function$