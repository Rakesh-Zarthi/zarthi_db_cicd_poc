CREATE OR REPLACE FUNCTION public.ac_merge_direct_bottom_up_json(p_direct_json jsonb, p_inherited_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$



DECLARE



    v_result jsonb;



    v_logs boolean := COALESCE(NULLIF(current_setting('admin.acl_logs', true), ''), 'false')::boolean;



BEGIN



    ------------------------------------------------------------

    -- LOG START

    ------------------------------------------------------------

    IF v_logs THEN

        RAISE NOTICE

'[ac_merge_direct_bottom_up_json] START direct_keys=% inherited_keys=%',

COALESCE(

    (SELECT string_agg(key, ',') FROM jsonb_object_keys(p_direct_json) AS key),

    'NULL'

),

COALESCE(

    (SELECT string_agg(key, ',') FROM jsonb_object_keys(p_inherited_json) AS key),

    'NULL'

);

    END IF;







    ------------------------------------------------------------

    -- NULL safety

    ------------------------------------------------------------

    p_direct_json    := COALESCE(p_direct_json,'{}'::jsonb);

    p_inherited_json := COALESCE(p_inherited_json,'{}'::jsonb);





    ------------------------------------------------------------

    -- MERGE DIRECT + INHERITED ACL JSON

    ------------------------------------------------------------

    SELECT COALESCE(

        jsonb_object_agg(perm, ids ORDER BY perm),

        '{}'::jsonb

    )

    INTO v_result

    FROM

    (

        SELECT

            perm,

            jsonb_agg(DISTINCT id ORDER BY id) AS ids

        FROM

        (

            ----------------------------------------------------

            -- DIRECT

            ----------------------------------------------------

            SELECT

                key AS perm,

                jsonb_array_elements_text(value)::bigint AS id

            FROM jsonb_each(p_direct_json)



            UNION ALL



            ----------------------------------------------------

            -- INHERITED (BOTTOM-UP)

            ----------------------------------------------------

            SELECT

                key,

                jsonb_array_elements_text(value)::bigint

            FROM jsonb_each(p_inherited_json)



        ) merged

        WHERE perm IN ('Select','Update','Delete')

        GROUP BY perm

    ) final;



    

    ------------------------------------------------------------

    -- LOG RESULT

    ------------------------------------------------------------

    IF v_logs THEN

        RAISE NOTICE

        '[ac_merge_direct_bottom_up_json] RESULT perms=% total_ids=%',

        (SELECT string_agg(key, ',') FROM jsonb_each(v_result)),

        (

            SELECT COALESCE(SUM(jsonb_array_length(value)),0)

            FROM jsonb_each(v_result)

        );

    END IF;



    ------------------------------------------------------------

    -- RETURN RESULT

    ------------------------------------------------------------

    RETURN v_result;





END;

$function$