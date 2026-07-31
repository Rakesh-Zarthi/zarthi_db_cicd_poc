CREATE OR REPLACE FUNCTION public.trg_log_request_state_change_history()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN



    IF TG_OP = 'INSERT' THEN



        NEW.state_change_timestamps :=

            jsonb_build_array(

                jsonb_build_object(

                    'status', NEW.status,

                    'at', CURRENT_TIMESTAMP

                )

            );



    ELSIF OLD.status IS DISTINCT FROM NEW.status THEN



        NEW.state_change_timestamps :=

            CASE

                WHEN jsonb_typeof(OLD.state_change_timestamps) = 'array'

                THEN OLD.state_change_timestamps

                ELSE '[]'::jsonb

            END

            ||

            jsonb_build_array(

                jsonb_build_object(

                    'status', NEW.status,

                    'at', CURRENT_TIMESTAMP

                )

            );



    END IF;



    RETURN NEW;



END;

$function$