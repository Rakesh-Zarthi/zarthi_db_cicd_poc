CREATE OR REPLACE FUNCTION public.automation_resequence_nodes_after_delete()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_fk bigint := OLD.ref_master_table_in_record_id;

    v_cur_seq int := 0;

    r RECORD;

BEGIN

    IF v_fk IS NULL THEN

        RETURN OLD;

    END IF;



    -- lock per-form to prevent concurrent resequences

    PERFORM pg_advisory_xact_lock(v_fk);



    FOR r IN

        SELECT in_record_id

        FROM public.master_node

        WHERE ref_master_table_in_record_id = v_fk

        ORDER BY node_sequence_number, in_record_id

    LOOP

        v_cur_seq := v_cur_seq + 1;

        UPDATE public.master_node

        SET node_sequence_number = v_cur_seq

        WHERE in_record_id = r.in_record_id;

    END LOOP;



    RETURN OLD;

END;

$function$