CREATE OR REPLACE FUNCTION public.master_node_005_001_fix_datatype_v1_0_0()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_updated_count INTEGER;

BEGIN

    RAISE NOTICE 'Starting datatype correction...';



   WITH physical_columns AS (

    SELECT

        mt.in_record_id AS master_table_id,

        mt.schema,

        mt.table_api_name,

        a.attname AS column_name,

        t.typname AS data_type

    FROM master_table mt

    JOIN pg_namespace n

        ON n.nspname = mt.schema

    JOIN pg_class c

        ON c.relname = mt.table_api_name

       AND c.relnamespace = n.oid

    JOIN pg_attribute a

        ON a.attrelid = c.oid

    JOIN pg_type t

        ON a.atttypid = t.oid

    WHERE a.attnum > 0

      AND NOT a.attisdropped

),



fk_info AS (

    SELECT

        lower(a.attname) AS column_name,

        lower(n.nspname) AS schema,

        lower(c.relname) AS table_name,

        EXISTS (

            SELECT 1

            FROM pg_constraint uc

            WHERE uc.conrelid = c.oid

              AND uc.contype IN ('u','p')

              AND a.attnum = ANY (uc.conkey)

              AND array_length(uc.conkey,1) = 1

        ) AND a.attnotnull AS is_unique_fk

    FROM pg_constraint con

    JOIN pg_class c ON c.oid = con.conrelid

    JOIN pg_namespace n ON n.oid = c.relnamespace

    JOIN unnest(con.conkey) WITH ORDINALITY AS k(attnum, ord) ON true

    JOIN pg_attribute a

      ON a.attrelid = con.conrelid

     AND a.attnum = k.attnum

    WHERE con.contype = 'f'

),



expected_types AS (

    SELECT

        p.master_table_id,

        p.schema,

        p.table_api_name,

        p.column_name,



        CASE

        WHEN p.column_name = 'in_record_id' THEN 'Record ID'

        WHEN p.column_name = 'in_record_name' THEN 'Record Name'

        WHEN p.column_name = 'in_added_time' THEN 'Custom Date'

        WHEN p.column_name = 'in_modified_time' THEN 'Custom Date'

        WHEN p.column_name = 'in_ref_master_table' THEN 'One-Many Lookup'

        WHEN p.column_name = 'in_ref_added_user_uuid' THEN 'UUID'

        WHEN p.column_name = 'in_ref_modified_user_uuid' THEN 'UUID'

        WHEN p.column_name = 'zoho_id' THEN 'Record ID'

        WHEN p.column_name IN (

            'in_ref_master_user_uuid',

            'in_ref_master_users_role_id',

            'in_ref_master_request_id',

            'in_ref_master_users_id'

        ) THEN 'Config JSON'



        WHEN f.column_name IS NOT NULL THEN

            CASE

                WHEN f.is_unique_fk THEN 'One-One Lookup'

                ELSE 'One-Many Lookup'

            END



        WHEN p.data_type = 'int8' THEN 'BIGINT'

        WHEN p.data_type = 'single_line_text' THEN 'Single Line Text'

        WHEN p.data_type = 'multiline_text' THEN 'Multiline Text'

        WHEN p.data_type = 'multiline_html' THEN 'Multiline HTML'

        WHEN p.data_type = 'multiline_html_text' THEN 'Multiline HTML Rich Text'

        WHEN p.data_type = 'email_address' THEN 'Email Address'

        WHEN p.data_type = 'url_address' THEN 'URL Address'

        WHEN p.data_type = 'phone_number' THEN 'Phone Number'

        WHEN p.data_type = 'postal_code' THEN 'Postal Code'

        WHEN p.data_type = 'city' THEN 'City'

        WHEN p.data_type = 'state' THEN 'State'

        WHEN p.data_type = 'country' THEN 'Country'

        WHEN p.data_type = 'address' THEN 'Address'

        WHEN p.data_type = 'attachment' THEN 'Attachment'

        WHEN p.data_type = 'record_name' THEN 'Record Name'

        WHEN p.data_type = 'record_id' THEN 'Record ID'

        WHEN p.data_type = 'uuid' THEN 'UUID'

        WHEN p.data_type = 'dropdown' THEN 'Single-Select Dropdown'

        WHEN p.data_type = '_dropdown' THEN 'Multi-Select Dropdown'

        WHEN p.data_type = 'data_type_dropdown' THEN 'DataType Dropdown'

        WHEN p.data_type = 'table_or_node_api_name' THEN 'Table/Node API Name'

        WHEN p.data_type = 'auto_number' THEN 'Auto Number'

        WHEN p.data_type = 'decimal1' THEN 'Decimal Number'

        WHEN p.data_type = 'levels' THEN 'Levels'

        WHEN p.data_type = 'percentage' THEN 'Percentage'

        WHEN p.data_type = 'config_json' THEN 'Config JSON'

        WHEN p.data_type = 'checkbox' THEN 'Checkbox'

        WHEN p.data_type = 'timefield' THEN 'Timefield'

        WHEN p.data_type = 'datetime' THEN 'Datetime'

        WHEN p.data_type = 'custom_date' THEN 'Custom Date'

        WHEN p.data_type = 'custom_number' THEN 'Custom Number'

        WHEN p.data_type = 'date_time' THEN 'Composite Datetime'

        WHEN p.data_type = 'permission_level' THEN 'Permission Level'



        ELSE NULL

        END AS expected_node_type



    FROM physical_columns p

    LEFT JOIN fk_info f

      ON f.column_name = p.column_name

     AND f.schema = p.schema

     AND f.table_name = p.table_api_name

)



UPDATE master_node mn

SET node_data_type = e.expected_node_type,

    in_modified_time = clock_timestamp()

FROM master_table mt, expected_types e

WHERE mn.ref_master_table_in_record_id = mt.in_record_id

AND e.master_table_id = mt.in_record_id

AND e.column_name = mn.node_api_name

AND mn.node_data_type IS DISTINCT FROM e.expected_node_type

AND e.expected_node_type IS NOT NULL;



    ----------------------------------------------------------------------

    -- Get affected rows

    ----------------------------------------------------------------------

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;



    RAISE NOTICE 'Datatype correction completed. Rows updated: %', v_updated_count;



END;

$function$