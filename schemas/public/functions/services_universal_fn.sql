CREATE OR REPLACE FUNCTION public.services_universal_fn()
 RETURNS TABLE(id record_id, root_parent record_id, immediate_parent record_id, immediate_module single_line_text, request_dependency single_line_text, module single_line_text, sku_id record_id, microservice_name single_line_text, summary single_line_text, status single_line_text, owner single_line_text, owner_account single_line_text, solution_type single_line_text, description single_line_text, collaborator single_line_text[], practice_id record_id, practice single_line_text, quantity custom_number, reason_for_hold single_line_text, file_id record_id, file_name single_line_text, file_size custom_number, file_type single_line_text, root_owner single_line_text, root_account single_line_text, immediate_owner_id record_id, immediate_owner single_line_text, immediate_owner_email email_address, immediate_account_id record_id, immediate_account single_line_text, root_parent_request_subject single_line_text, immediate_parent_request_subject single_line_text, owner_email email_address, owner_id record_id, dependent_requests bigint, closed_dependent_requests bigint, queued_timestamp timestamp with time zone, backlog_timestamp timestamp with time zone, received_timestamp timestamp with time zone, assigned_timestamp timestamp with time zone, in_progress_timestamp timestamp with time zone, on_hold_timestamp timestamp with time zone, complete_timestamp timestamp with time zone, closed_timestamp timestamp with time zone, created_time timestamp with time zone, added_user single_line_text, added_user_email email_address, root_module single_line_text, request_origin single_line_text, label single_line_text, no_open_action boolean, no_dependent_solution boolean, dependent_request_pending boolean, customer_action_pending boolean, pause_by_customer boolean, scoping boolean, documentation boolean, quality_check boolean, execution boolean, complete boolean, root_account_id record_id)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$

BEGIN



    -- Set tenant context

    PERFORM set_config(

        'app.CURRENT_APP_ID',

        current_setting('app.CURRENT_APP_ID', true),

        true

    );



    RETURN QUERY



    SELECT *

    FROM public.services_universal; -- uses your corrected domain-safe view



END;

$function$