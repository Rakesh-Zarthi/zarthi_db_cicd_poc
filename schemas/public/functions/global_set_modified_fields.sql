CREATE OR REPLACE FUNCTION public.global_set_modified_fields()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_user_uuid uuid := current_setting('app.current_user_id', true)::uuid;

    v_new       jsonb := to_jsonb(NEW);

BEGIN



    ------------------------------------------------------------------

    -- Prevent immutable key changes

    ------------------------------------------------------------------

  --  IF v_new ? 'in_record_id' THEN

  --      IF NEW.in_record_id IS DISTINCT FROM OLD.in_record_id THEN

  --          RAISE EXCEPTION 'in_record_id cannot be changed';

  --      END IF;

--    END IF;



  --  IF v_new ? 'in_ref_added_user_uuid' THEN

 ---       IF NEW.in_ref_added_user_uuid IS DISTINCT FROM OLD.in_ref_added_user_uuid THEN

  --          RAISE EXCEPTION 'in_ref_added_user_uuid cannot be changed';

  --      END IF;

  --  END IF;



  --  IF v_new ? 'in_added_time' THEN

   --     IF NEW.in_added_time IS DISTINCT FROM OLD.in_added_time THEN

   --         RAISE EXCEPTION 'in_added_time cannot be changed';

  --      END IF;

 --   END IF;



  --  IF v_new ? 'in_ref_master_table' THEN

 --       IF NEW.in_ref_master_table IS DISTINCT FROM OLD.in_ref_master_table THEN

  --          RAISE EXCEPTION 'in_ref_master_table cannot be changed';

  --      END IF;

 --   END IF;



    ------------------------------------------------------------------

    -- Set modified time/user

    ------------------------------------------------------------------

    IF v_new ? 'in_modified_time' THEN

        NEW.in_modified_time := CURRENT_TIMESTAMP;

    END IF;



    IF v_new ? 'in_ref_modified_user_uuid' THEN

        NEW.in_ref_modified_user_uuid :=

            COALESCE(NEW.in_ref_modified_user_uuid, v_user_uuid);

    END IF;



    RETURN NEW;

END;

$function$