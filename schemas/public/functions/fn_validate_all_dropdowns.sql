CREATE OR REPLACE FUNCTION public.fn_validate_all_dropdowns()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    rec        RECORD;

    row_json   jsonb := to_jsonb(NEW);

    raw_value  jsonb;

    val_text   text;

    val_array  text[];

BEGIN

    ----------------------------------------------------------------------

    -- Iterate only dropdown columns for this table

    ----------------------------------------------------------------------

    FOR rec IN

        SELECT

            mn.node_api_name,

            mn.node_data_type,

            mn.dropdown_values::text[]

        FROM public.master_node mn

        JOIN public.master_table mt

              ON mt.in_record_id = mn.ref_master_table_in_record_id

        WHERE mt.table_api_name = TG_TABLE_NAME

          AND mn.node_data_type IN (

                'Single-Select Dropdown',

                'Multi-Select Dropdown'

          )

    LOOP

        ------------------------------------------------------------------

        -- Skip column if not present in NEW (partial update safety)

        ------------------------------------------------------------------

        IF NOT (row_json ? rec.node_api_name) THEN

            CONTINUE;

        END IF;



        raw_value := row_json -> rec.node_api_name;



        ------------------------------------------------------------------

        -- Ignore real SQL NULL

        ------------------------------------------------------------------

        IF raw_value IS NULL OR raw_value = 'null'::jsonb THEN

            CONTINUE;

        END IF;



        ------------------------------------------------------------------

        -- SINGLE SELECT DROPDOWN (CASE-SENSITIVE)

        ------------------------------------------------------------------

        IF rec.node_data_type = 'Single-Select Dropdown' THEN



            -- Must be scalar

            IF jsonb_typeof(raw_value) <> 'string' THEN

                RAISE EXCEPTION

                    'Invalid value for Single-Select Dropdown "%": expected string, got %',

                    rec.node_api_name,

                    jsonb_typeof(raw_value);

            END IF;



            val_text := trim(both '"' FROM raw_value::text);



            -- Reject empty string

            IF val_text = '' THEN

                RAISE EXCEPTION

                    'Empty value not allowed for Single-Select Dropdown "%". Allowed: %',

                    rec.node_api_name,

                    rec.dropdown_values;

            END IF;



            -- Case-sensitive validation

            IF NOT (val_text = ANY(rec.dropdown_values)) THEN

                RAISE EXCEPTION

                    'Invalid dropdown value "%" for field "%". Allowed (case-sensitive): %',

                    val_text,

                    rec.node_api_name,

                    rec.dropdown_values;

            END IF;



        ------------------------------------------------------------------

        -- MULTI SELECT DROPDOWN (CASE-SENSITIVE)

        ------------------------------------------------------------------

        ELSE  -- Multi-Select Dropdown



            IF jsonb_typeof(raw_value) = 'array' THEN

                SELECT array_agg(elem)

                INTO val_array

                FROM jsonb_array_elements_text(raw_value) AS elem;



            ELSIF jsonb_typeof(raw_value) = 'string'

                  AND raw_value::text LIKE '"{%' THEN

                val_array := trim(both '"' FROM raw_value::text)::text[];



            ELSE

                RAISE EXCEPTION

                    'Invalid value for Multi-Select Dropdown "%": expected JSON array or postgres array literal, got %',

                    rec.node_api_name,

                    raw_value;

            END IF;



            -- Empty array allowed

            IF val_array IS NULL OR array_length(val_array,1) IS NULL THEN

                CONTINUE;

            END IF;



            -- Case-sensitive containment check

            IF NOT (val_array <@ rec.dropdown_values) THEN

                RAISE EXCEPTION

                    'Invalid Multi-Select Dropdown values "%" for field "%". Allowed (case-sensitive): %',

                    val_array,

                    rec.node_api_name,

                    rec.dropdown_values;

            END IF;



        END IF;

    END LOOP;



    RETURN NEW;

END;

$function$