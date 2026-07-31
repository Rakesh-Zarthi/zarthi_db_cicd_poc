CREATE OR REPLACE FUNCTION public.trg_update_gen_requests_status_labels()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

BEGIN



    -- Skip processing if none of the status flags changed

    IF TG_OP = 'UPDATE'

       AND ROW (

            NEW.gen_problem_no_dependent_solution,

            NEW.gen_problem_pending_dependent_solution,

            NEW.gen_no_open_actionable,

            NEW.gen_pending_requirement_gathering,

            NEW.gen_pending_approval,

            NEW.gen_documentation,

            NEW.gen_pending_signoff,

            NEW.gen_execution,

            NEW.gen_paused_by_customer,

            NEW.gen_quality_check

       )

       IS NOT DISTINCT FROM

       ROW (

            OLD.gen_problem_no_dependent_solution,

            OLD.gen_problem_pending_dependent_solution,

            OLD.gen_no_open_actionable,

            OLD.gen_pending_requirement_gathering,

            OLD.gen_pending_approval,

            OLD.gen_documentation,

            OLD.gen_pending_signoff,

            OLD.gen_execution,

            OLD.gen_paused_by_customer,

            OLD.gen_quality_check

       )

    THEN

        RETURN NEW;

    END IF;



    NEW.gen_requests_status_lables :=

    (

        SELECT array_agg(label::dropdown ORDER BY seq)

        FROM (

            VALUES

                (1,  'Problem - No Dependent Solution',      NEW.gen_problem_no_dependent_solution),

                (2,  'Problem - Pending Dependent Solution', NEW.gen_problem_pending_dependent_solution),

                (3,  'No Open Actionable',                   NEW.gen_no_open_actionable),

                (4,  'Pending Requirement Gathering',        NEW.gen_pending_requirement_gathering),

                (5,  'Pending Approval',                     NEW.gen_pending_approval),

                (6,  'Documentation',                        NEW.gen_documentation),

                (7,  'Pending Sign-Off',                     NEW.gen_pending_signoff),

                (8,  'Execution',                            NEW.gen_execution),

                (9,  'Paused By Customer',                   NEW.gen_paused_by_customer),

                (10, 'Quality Check',                        NEW.gen_quality_check)

        ) AS t(seq, label, is_true)

        WHERE is_true

    );



    RETURN NEW;



END;

$function$