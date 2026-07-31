CREATE OR REPLACE FUNCTION public.master_table_manager_wrapper()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$

BEGIN



    ----------------------------------------------------------

    -- INSERT

    ----------------------------------------------------------

    IF TG_OP = 'INSERT' THEN



        ------------------------------------------------------

        -- RLS management

        ------------------------------------------------------

        IF NEW.rls_enabled THEN



            PERFORM public.master_table_set_rls(

                NEW.in_record_id,

                true,

                false

            );



            PERFORM public.master_table_create_row_level_security_policy(

                NEW.in_record_id

            );



        ELSE



            PERFORM public.master_table_set_rls(

                NEW.in_record_id,

                false,

                false

            );



        END IF;



        RETURN NEW;

    END IF;



    ----------------------------------------------------------

    -- UPDATE

    ----------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN







        ------------------------------------------------------

        -- RLS change

        ------------------------------------------------------

        IF NEW.rls_enabled IS DISTINCT FROM OLD.rls_enabled THEN



            IF NEW.rls_enabled THEN



                PERFORM public.master_table_set_rls(

                    NEW.in_record_id,

                    true,

                    false

                );



                PERFORM public.master_table_create_row_level_security_policy(

                    NEW.in_record_id

                );



            ELSE



                PERFORM public.master_table_set_rls(

                    NEW.in_record_id,

                    false,

                    false

                );



            END IF;



        END IF;



        RETURN NEW;

    END IF;



    ----------------------------------------------------------

    -- DELETE

    ----------------------------------------------------------

    IF TG_OP = 'DELETE' THEN



        ------------------------------------------------------

        -- Disable RLS

        ------------------------------------------------------

        PERFORM public.master_table_set_rls(

            OLD.in_record_id,

            false,

            false

        );



        RETURN OLD;



    END IF;



    RETURN NULL;



END;

$function$