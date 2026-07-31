CREATE OR REPLACE FUNCTION workflow.import_step_status(p_step_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

BEGIN



    INSERT INTO workflow.step_status

    (

        in_record_name,

        ref_workflow_step_in_record_id,

        ref_workflow_step_status_master_in_record_id,

        display_order,

        is_default,

        is_active

    )

    SELECT

        s.step_name || ' - ' || sm.step_status_name,

        s.in_record_id,

        sm.in_record_id,

        sm.display_order,

        sm.is_default,

        TRUE

    FROM workflow.step s

    CROSS JOIN workflow.step_status_master sm

    WHERE s.in_record_id = p_step_id

    ON CONFLICT

    (

        ref_workflow_step_in_record_id,

        ref_workflow_step_status_master_in_record_id

    )

    DO NOTHING;



END;

$function$