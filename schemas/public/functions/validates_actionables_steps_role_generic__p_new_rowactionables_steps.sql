CREATE OR REPLACE FUNCTION public.validates_actionables_steps_role_generic(p_new_row actionables_steps)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_actionable_name text;

    v_request_id bigint;

    v_step_owner bigint;

BEGIN

    ------------------------------------------------------------------

    -- Resolve actionable

    ------------------------------------------------------------------

    SELECT actionable_name,

           request_subject

    INTO v_actionable_name,

         v_request_id

    FROM public.actionables

    WHERE in_record_id = p_new_row.ref_actionables_in_record_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

            'Actionable % not found',

            p_new_row.ref_actionables_in_record_id

            USING ERRCODE = '23503';

    END IF;



    ------------------------------------------------------------------

    -- Role based step must have owner

    ------------------------------------------------------------------

    IF p_new_row.ref_users_in_record_id_owner IS NULL THEN

        RAISE EXCEPTION

            'Role_Based step requires ref_users_in_record_id_owner (actionable "%", step %)',

            v_actionable_name,

            p_new_row.step_no

            USING ERRCODE = '23514';

    END IF;



    ------------------------------------------------------------------

    -- Owner must exist

    ------------------------------------------------------------------

    SELECT in_record_id

    INTO v_step_owner

    FROM public.users

    WHERE in_record_id = p_new_row.ref_users_in_record_id_owner;



    IF v_step_owner IS NULL THEN

        RAISE EXCEPTION

            'Invalid step owner % for Role_Based step (actionable "%", step %)',

            p_new_row.ref_users_in_record_id_owner,

            v_actionable_name,

            p_new_row.step_no

            USING ERRCODE = '23503';

    END IF;



END;

$function$