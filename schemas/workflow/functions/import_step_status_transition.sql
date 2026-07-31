CREATE OR REPLACE FUNCTION workflow.import_step_status_transition()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'workflow', 'public'
AS $function$

DECLARE

    v_from_id bigint;

    v_to_id bigint;

    v_display_order integer := 1;

BEGIN



    --------------------------------------------------------------------------

    -- Draft -> Planned

    --------------------------------------------------------------------------



    SELECT in_record_id

    INTO v_from_id

    FROM workflow.step_status_master

    WHERE step_status_api_name = 'draft';



    SELECT in_record_id

    INTO v_to_id

    FROM workflow.step_status_master

    WHERE step_status_api_name = 'planned';



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_default,

        is_system,

        is_active,

        description

    )

    VALUES

    (

        'Draft -> Planned',

        v_from_id,

        v_to_id,

        'Draft -> Planned',

        'draft_to_planned',

        v_display_order,

        TRUE,

        TRUE,

        TRUE,

        'Move draft step to planned state'

    )

    ON CONFLICT

    (

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to

    )

    DO NOTHING;



    v_display_order := v_display_order + 1;



    --------------------------------------------------------------------------

    -- Draft -> Discard

    --------------------------------------------------------------------------



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_system

    )

    SELECT

        'Draft -> Discard',

        s1.in_record_id,

        s2.in_record_id,

        'Draft -> Discard',

        'draft_to_discard',

        v_display_order,

        TRUE

    FROM workflow.step_status_master s1

    CROSS JOIN workflow.step_status_master s2

    WHERE s1.step_status_api_name = 'draft'

      AND s2.step_status_api_name = 'discard'

    ON CONFLICT DO NOTHING;



    v_display_order := v_display_order + 1;



    --------------------------------------------------------------------------

    -- Planned -> Scheduled

    --------------------------------------------------------------------------



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_system

    )

    SELECT

        'Planned -> Scheduled',

        s1.in_record_id,

        s2.in_record_id,

        'Planned -> Scheduled',

        'planned_to_scheduled',

        v_display_order,

        TRUE

    FROM workflow.step_status_master s1

    CROSS JOIN workflow.step_status_master s2

    WHERE s1.step_status_api_name = 'planned'

      AND s2.step_status_api_name = 'scheduled'

    ON CONFLICT DO NOTHING;



    v_display_order := v_display_order + 1;



    --------------------------------------------------------------------------

    -- Planned -> Open

    --------------------------------------------------------------------------



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_default,

        is_system

    )

    SELECT

        'Planned -> Open',

        s1.in_record_id,

        s2.in_record_id,

        'Planned -> Open',

        'planned_to_open',

        v_display_order,

        TRUE,

        TRUE

    FROM workflow.step_status_master s1

    CROSS JOIN workflow.step_status_master s2

    WHERE s1.step_status_api_name = 'planned'

      AND s2.step_status_api_name = 'open'

    ON CONFLICT DO NOTHING;



    v_display_order := v_display_order + 1;



    --------------------------------------------------------------------------

    -- Planned -> Discard

    --------------------------------------------------------------------------



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_system

    )

    SELECT

        'Planned -> Discard',

        s1.in_record_id,

        s2.in_record_id,

        'Planned -> Discard',

        'planned_to_discard',

        v_display_order,

        TRUE

    FROM workflow.step_status_master s1

    CROSS JOIN workflow.step_status_master s2

    WHERE s1.step_status_api_name = 'planned'

      AND s2.step_status_api_name = 'discard'

    ON CONFLICT DO NOTHING;



    v_display_order := v_display_order + 1;



    --------------------------------------------------------------------------

    -- Scheduled -> Open

    --------------------------------------------------------------------------



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_default,

        is_system

    )

    SELECT

        'Scheduled -> Open',

        s1.in_record_id,

        s2.in_record_id,

        'Scheduled -> Open',

        'scheduled_to_open',

        v_display_order,

        TRUE,

        TRUE

    FROM workflow.step_status_master s1

    CROSS JOIN workflow.step_status_master s2

    WHERE s1.step_status_api_name = 'scheduled'

      AND s2.step_status_api_name = 'open'

    ON CONFLICT DO NOTHING;



    v_display_order := v_display_order + 1;



    --------------------------------------------------------------------------

    -- Scheduled -> Discard

    --------------------------------------------------------------------------



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_system

    )

    SELECT

        'Scheduled -> Discard',

        s1.in_record_id,

        s2.in_record_id,

        'Scheduled -> Discard',

        'scheduled_to_discard',

        v_display_order,

        TRUE

    FROM workflow.step_status_master s1

    CROSS JOIN workflow.step_status_master s2

    WHERE s1.step_status_api_name = 'scheduled'

      AND s2.step_status_api_name = 'discard'

    ON CONFLICT DO NOTHING;



    v_display_order := v_display_order + 1;



    --------------------------------------------------------------------------

    -- Open -> Complete

    --------------------------------------------------------------------------



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_default,

        is_system

    )

    SELECT

        'Open -> Complete',

        s1.in_record_id,

        s2.in_record_id,

        'Open -> Complete',

        'open_to_complete',

        v_display_order,

        TRUE,

        TRUE

    FROM workflow.step_status_master s1

    CROSS JOIN workflow.step_status_master s2

    WHERE s1.step_status_api_name = 'open'

      AND s2.step_status_api_name = 'complete'

    ON CONFLICT DO NOTHING;



    v_display_order := v_display_order + 1;



    --------------------------------------------------------------------------

    -- Open -> Discard

    --------------------------------------------------------------------------



    INSERT INTO workflow.step_status_transition

    (

        in_record_name,

        ref_step_status_in_record_id_from,

        ref_step_status_in_record_id_to,

        transition_name,

        transition_api_name,

        display_order,

        is_system

    )

    SELECT

        'Open -> Discard',

        s1.in_record_id,

        s2.in_record_id,

        'Open -> Discard',

        'open_to_discard',

        v_display_order,

        TRUE

    FROM workflow.step_status_master s1

    CROSS JOIN workflow.step_status_master s2

    WHERE s1.step_status_api_name = 'open'

      AND s2.step_status_api_name = 'discard'

    ON CONFLICT DO NOTHING;



END;

$function$