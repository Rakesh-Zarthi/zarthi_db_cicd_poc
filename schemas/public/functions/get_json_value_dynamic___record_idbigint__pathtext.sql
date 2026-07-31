CREATE OR REPLACE FUNCTION public.get_json_value_dynamic(_record_id bigint, _path text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_json jsonb;

    v_result jsonb;

    v_path_elems text[];

    v_elem text;

    v_index int;

BEGIN

    -- Fetch JSON data for the given record

    SELECT json_actionable_data

    INTO v_json

    FROM public.json_actionable

    WHERE master_id = _record_id;



    IF v_json IS NULL THEN

        RAISE NOTICE 'No JSON found for master_id %', _record_id;

        RETURN NULL;

    END IF;



    -- Split the dot-separated path into an array

    v_path_elems := string_to_array(_path, '.');

    v_result := v_json;



    -- Traverse JSON dynamically

    FOREACH v_elem IN ARRAY v_path_elems LOOP

        -- Check if element is a numeric array index

        IF v_elem ~ '^[0-9]+$' THEN

            v_index := v_elem::int;

            v_result := (v_result->v_index);

        ELSE

            v_result := (v_result->v_elem);

        END IF;



        -- Stop if we reach null or invalid path

        IF v_result IS NULL THEN

            RETURN NULL;

        END IF;

    END LOOP;



    -- Return final value as text

    RETURN v_result::text;

END;

$function$