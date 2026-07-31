CREATE OR REPLACE FUNCTION public.automation_validate_node_sequences()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_fk bigint;

    v_dup_count int;

    v_null_count int;

    v_gaps jsonb := '[]'::jsonb;

    v_expected_seq int;

    r RECORD;

BEGIN

    /*

      This trigger function must be attached to a statement-level trigger with:

        REFERENCING NEW TABLE AS inserted_nodes_temp

      and that temp table should contain in_record_id values (or ref_master_table_in_record_id).

    */



    -- Iterate over distinct affected forms in the temp table

    FOR v_fk IN

        SELECT DISTINCT mn.ref_master_table_in_record_id

        FROM public.master_node mn

        JOIN inserted_nodes_temp t ON mn.in_record_id = t.in_record_id

        WHERE mn.ref_master_table_in_record_id IS NOT NULL

    LOOP

        -- 1) Null sequences check

        SELECT COUNT(*) INTO v_null_count

        FROM public.master_node

        WHERE ref_master_table_in_record_id = v_fk

          AND node_sequence_number IS NULL;



        IF v_null_count > 0 THEN

            RAISE EXCEPTION 'Found % null node_sequence_number(s) for form id %', v_null_count, v_fk;

        END IF;



        -- 2) Duplicate sequence check

        SELECT COUNT(*) INTO v_dup_count

        FROM (

            SELECT node_sequence_number, COUNT(*) AS ct

            FROM public.master_node

            WHERE ref_master_table_in_record_id = v_fk

            GROUP BY node_sequence_number

            HAVING COUNT(*) > 1

        ) t;



        IF v_dup_count > 0 THEN

            RAISE EXCEPTION 'Duplicate node_sequence_number(s) detected for form id %', v_fk;

        END IF;



        -- 3) Fix gaps: resequence from 1..N and collect changes

        v_expected_seq := 1;

        FOR r IN

            SELECT in_record_id, node_label, node_sequence_number

            FROM public.master_node

            WHERE ref_master_table_in_record_id = v_fk

            ORDER BY node_sequence_number, in_record_id

        LOOP

            IF r.node_sequence_number IS DISTINCT FROM v_expected_seq THEN

                UPDATE public.master_node

                SET node_sequence_number = v_expected_seq

                WHERE in_record_id = r.in_record_id;



                v_gaps := v_gaps || jsonb_build_object(

                    'node_label', r.node_label,

                    'old_sequence', r.node_sequence_number,

                    'new_sequence', v_expected_seq

                );

            END IF;

            v_expected_seq := v_expected_seq + 1;

        END LOOP;



        -- 4) Log fixes if any happened for this form

        IF jsonb_array_length(v_gaps) > 0 THEN

            INSERT INTO public.security_events (

                attempted_user, table_name, operation, message, attempted_data, created_at

            ) VALUES (

                current_user,

                (SELECT table_api_name FROM public.master_table WHERE in_record_id = v_fk),

                'BULK RESEQUENCE FIX',

                format('Fixed sequence gaps/duplicates for form id %s', v_fk),

                v_gaps,

                now()

            );

            -- reset v_gaps for next form

            v_gaps := '[]'::jsonb;

        END IF;

    END LOOP;



    RETURN NULL; -- statement-level trigger returns NULL

END;

$function$