CREATE OR REPLACE FUNCTION public.cns_get_new_fk_value(p_new record, p_column_name text)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_value bigint;

BEGIN

    EXECUTE format('SELECT ($1).%I', p_column_name)

    INTO v_value

    USING p_new;



    RETURN v_value;

END;

$function$