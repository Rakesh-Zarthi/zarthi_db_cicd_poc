CREATE OR REPLACE FUNCTION public.master_table_create_rls_insert_policy(p_master_table_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE

    v_schema text;

    v_table  text;



BEGIN



----------------------------------------------------------

-- Resolve metadata

----------------------------------------------------------



SELECT schema, table_api_name

INTO v_schema, v_table

FROM public.master_table

WHERE in_record_id = p_master_table_id;



IF v_schema IS NULL THEN

    RAISE EXCEPTION 'master_table id % not found', p_master_table_id;

END IF;



----------------------------------------------------------

-- Ensure RLS enabled

----------------------------------------------------------



EXECUTE format(

'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',

v_schema,

v_table

);



----------------------------------------------------------

-- Create INSERT policy

----------------------------------------------------------



EXECUTE format($sql$



DROP POLICY IF EXISTS rls_%1$s_insert ON %2$I.%1$I;



CREATE POLICY rls_%1$s_insert

ON %2$I.%1$I

FOR INSERT

WITH CHECK (



--------------------------------------------------

-- SYSTEM OVERRIDE

--------------------------------------------------



current_setting('app.system_write', true) = 'true'



OR (



--------------------------------------------------

-- VALID APPLICATION

--------------------------------------------------



public.app_current_app_is_valid_policy_helper()



AND



--------------------------------------------------

-- PERMISSION RESOLUTION

--------------------------------------------------



CASE public.app_scope_policy_helper(%3$L,'insert')



WHEN 1 THEN TRUE



WHEN 2 THEN

    public.app_current_user_is_valid_policy_helper()



WHEN 3 THEN

(

    public.app_current_user_is_valid_policy_helper()

    AND

    public.app_insert_uuid_policy_helper(%3$L)

)



ELSE FALSE



END



)



);



$sql$, v_table, v_schema, v_table);



END;



$function$