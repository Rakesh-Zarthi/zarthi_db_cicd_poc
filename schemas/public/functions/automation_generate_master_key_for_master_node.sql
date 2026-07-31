CREATE OR REPLACE FUNCTION public.automation_generate_master_key_for_master_node()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_table_api_name text;

    v_node_label     text;

    v_node_api_name  text;

BEGIN

    --------------------------------------------------------------------

    -- 1∩╕ÅΓâú Get parent form API name

    --------------------------------------------------------------------

    SELECT mt.table_api_name

    INTO v_table_api_name

    FROM public.master_table mt

    WHERE mt.in_record_id = COALESCE(NEW.ref_master_table_in_record_id, OLD.ref_master_table_in_record_id)

    LIMIT 1;



    IF v_table_api_name IS NULL THEN

        RAISE EXCEPTION 

            'Γ¥î Unable to determine table_api_name for ref_master_table_in_record_id=%',

            COALESCE(NEW.ref_master_table_in_record_id, OLD.ref_master_table_in_record_id);

    END IF;



    --------------------------------------------------------------------

    -- 2∩╕ÅΓâú Normalize values

    --------------------------------------------------------------------

    v_table_api_name :=

        lower(regexp_replace(trim(v_table_api_name), '[^a-zA-Z0-9]+', '_', 'g'));



    v_node_label :=

        trim(coalesce(NEW.node_label, ''));



    v_node_api_name :=

        lower(regexp_replace(trim(NEW.node_api_name), '[^a-zA-Z0-9]+', '_', 'g'));



    --------------------------------------------------------------------

    -- 3∩╕ÅΓâú REGENERATE master-key value

    -- Format: <form_api>_<node_label>_<node_api>

    --------------------------------------------------------------------

    NEW.in_record_name := v_table_api_name || '_' || v_node_label || '_' || v_node_api_name;



    RETURN NEW;

END;

$function$