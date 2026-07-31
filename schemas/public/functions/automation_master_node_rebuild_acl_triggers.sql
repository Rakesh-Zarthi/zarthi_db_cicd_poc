CREATE OR REPLACE FUNCTION public.automation_master_node_rebuild_acl_triggers()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_old_table_id bigint;

    v_new_table_id bigint;

BEGIN



------------------------------------------------------------------

-- Skip system writes

------------------------------------------------------------------

IF current_setting('app.system_write', true) = 'true' THEN

    RETURN COALESCE(NEW, OLD);

END IF;



------------------------------------------------------------------

-- Ignore non-lookup node changes

------------------------------------------------------------------

IF TG_OP = 'INSERT' THEN

    IF NEW.node_data_type NOT IN ('One-One Lookup','One-Many Lookup') THEN

        RETURN NEW;

    END IF;

END IF;



IF TG_OP = 'DELETE' THEN

    IF OLD.node_data_type NOT IN ('One-One Lookup','One-Many Lookup') THEN

        RETURN OLD;

    END IF;

END IF;



IF TG_OP = 'UPDATE' THEN

    IF NEW.node_data_type NOT IN ('One-One Lookup','One-Many Lookup')

       AND OLD.node_data_type NOT IN ('One-One Lookup','One-Many Lookup') THEN

        RETURN NEW;

    END IF;

END IF;



------------------------------------------------------------------

-- Resolve table ids

------------------------------------------------------------------

v_old_table_id := OLD.ref_master_table_in_record_id;

v_new_table_id := NEW.ref_master_table_in_record_id;



------------------------------------------------------------------

-- INSERT

------------------------------------------------------------------

IF TG_OP = 'INSERT' THEN



    IF v_new_table_id IS NOT NULL THEN

        PERFORM public.master_table_rebuild_self_access_control_trigger(

            v_new_table_id, TRUE

        );

    END IF;



------------------------------------------------------------------

-- UPDATE

------------------------------------------------------------------

ELSIF TG_OP = 'UPDATE' THEN



    IF v_old_table_id IS DISTINCT FROM v_new_table_id THEN



        IF v_old_table_id IS NOT NULL THEN

            PERFORM public.master_table_rebuild_self_access_control_trigger(

                v_old_table_id, TRUE

            );





        END IF;



        IF v_new_table_id IS NOT NULL THEN

            PERFORM public.master_table_rebuild_self_access_control_trigger(

                v_new_table_id, TRUE

            );





        END IF;



    ELSE

        IF v_new_table_id IS NOT NULL THEN

            PERFORM public.master_table_rebuild_self_access_control_trigger(

                v_new_table_id, TRUE

            );





        END IF;

    END IF;



------------------------------------------------------------------

-- DELETE

------------------------------------------------------------------

ELSIF TG_OP = 'DELETE' THEN



    IF v_old_table_id IS NOT NULL THEN

        PERFORM public.master_table_rebuild_self_access_control_trigger(

            v_old_table_id, TRUE

        );





    END IF;



END IF;



RETURN COALESCE(NEW, OLD);



END;

$function$