CREATE OR REPLACE FUNCTION public.mtac_users_validate_acl_table_permission()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_node_permission public."_dropdown";

BEGIN

    /*

     * Fetch parent node permission

     */

    SELECT n.permission

    INTO v_node_permission

    FROM public.master_node_access_control_users n

    WHERE n.ref_master_table_access_control_users_in_record_id = NEW.in_record_id

      AND n.ref_master_node_in_record_id_to = NEW.ref_master_node_in_record_id_from;



    /*

     * No parent node ACL found

     */

    IF v_node_permission IS NULL THEN

        RETURN NEW;

    END IF;



    /*

     * Read => Select only

     */

    IF v_node_permission = ARRAY['Read']::public."_dropdown" THEN

        IF NEW.permission <>

           ARRAY['Select']::public."_dropdown"

        THEN

            RAISE EXCEPTION

                'When node permission is {Read}, table permission can only be {Select}.';

        END IF;

    END IF;



    /*

     * Read + Write or Write present

     */

    IF v_node_permission &&

       ARRAY['Write']::public."_dropdown"

    THEN

        IF NOT (

            NEW.permission <@

            ARRAY[

                'Select',

                'Link',

                'Insert',

                'Update',

                'Delete'

            ]::public."_dropdown"

        )

        THEN

            RAISE EXCEPTION

                'When node permission contains {Write}, only {Select, Link, Insert, Update, Delete} are allowed.';

        END IF;

    END IF;



    RETURN NEW;

END;

$function$