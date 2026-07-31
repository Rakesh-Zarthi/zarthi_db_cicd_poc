CREATE OR REPLACE FUNCTION public.etl_sync_requests_immediate_parent()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN



    ------------------------------------------------------------------

    -- Prevent recursive execution

    ------------------------------------------------------------------

    IF pg_trigger_depth() > 1 THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- Requests Services

    ------------------------------------------------------------------

    IF TG_TABLE_NAME = 'requests_services' THEN



        UPDATE public.requests

        SET ref_requests_in_record_id_immediate_parent = NEW.immediate_parent

        WHERE in_record_id = NEW.ref_requests_record_id

          AND ref_requests_in_record_id_immediate_parent

                IS DISTINCT FROM NEW.immediate_parent;



    ------------------------------------------------------------------

    -- Requests Staffing

    ------------------------------------------------------------------

    ELSIF TG_TABLE_NAME = 'requests_staffing' THEN



        UPDATE public.requests

        SET ref_requests_in_record_id_immediate_parent = NEW.immediate_parent

        WHERE in_record_id = NEW.ref_requests_record_id

          AND ref_requests_in_record_id_immediate_parent

                IS DISTINCT FROM NEW.immediate_parent;



    ------------------------------------------------------------------

    -- Requests Roles

    ------------------------------------------------------------------

    ELSIF TG_TABLE_NAME = 'requests_sku_roles' THEN



        UPDATE public.requests

        SET ref_requests_in_record_id_immediate_parent = NEW.immediate_parent

        WHERE in_record_id = NEW.ref_requests_in_record_id

          AND ref_requests_in_record_id_immediate_parent

                IS DISTINCT FROM NEW.immediate_parent;



    END IF;



    RETURN NEW;



END;

$function$