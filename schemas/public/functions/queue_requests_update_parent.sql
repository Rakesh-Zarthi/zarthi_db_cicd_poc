CREATE OR REPLACE FUNCTION public.queue_requests_update_parent()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE

    v_request_id bigint;

BEGIN

    IF TG_OP <> 'UPDATE' THEN

        RETURN NEW;

    END IF;



    IF NEW.immediate_parent IS DISTINCT FROM OLD.immediate_parent THEN



        v_request_id :=

            COALESCE(

                (to_jsonb(NEW)->>'ref_requests_record_id')::bigint,

                (to_jsonb(NEW)->>'ref_requests_in_record_id')::bigint

            );



        IF NEW.immediate_parent = v_request_id THEN

            RETURN NEW;

        END IF;



        PERFORM pg_notify(

            'requests_parent_update',

            v_request_id::text

        );

    END IF;



    RETURN NEW;

END;

$function$