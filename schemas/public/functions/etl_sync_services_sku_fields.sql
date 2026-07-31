CREATE OR REPLACE FUNCTION public.etl_sync_services_sku_fields()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- =====================

    -- INSERT HANDLING

    -- =====================

    IF TG_OP = 'INSERT' THEN

        -- Forward sync (microservice ΓåÆ sku)

        NEW.sku_name := COALESCE(NEW.sku_name, NEW.microservice_name);

        NEW.sku_type := COALESCE(NEW.sku_type, NEW.microservice_type);

        NEW.sku_status := COALESCE(NEW.sku_status, NEW.microservice_status);

        NEW.sku_description := COALESCE(NEW.sku_description, NEW.microservice_description);

        NEW.sku_pricing_unit := COALESCE(NEW.sku_pricing_unit, NEW.microservice_pricing_unit);



        NEW.ref_accounts_in_record_id := COALESCE(NEW.ref_accounts_in_record_id, NEW.ref_accounts_in_record_id_account_name);

        NEW.ref_practices_in_record_id := COALESCE(NEW.ref_practices_in_record_id, NEW.ref_practice_id);

        NEW.ref_practices_in_record_id_bill_to := COALESCE(NEW.ref_practices_in_record_id_bill_to, NEW.bill_to_corporate_unit);

        NEW.ref_users_in_record_id_bill_to := COALESCE(NEW.ref_users_in_record_id_bill_to, NEW.bill_to_individual_name);

        NEW.ref_kpi_in_record_id := COALESCE(NEW.ref_kpi_in_record_id, NEW.kpi);

        NEW.ref_master_table_in_record_id_deliverable := COALESCE(NEW.ref_master_table_in_record_id_deliverable, NEW.deliverable_db);



        -- Reverse sync (sku ΓåÆ microservice) if source missing

        NEW.microservice_name := COALESCE(NEW.microservice_name, NEW.sku_name);

        NEW.microservice_type := COALESCE(NEW.microservice_type, NEW.sku_type);

        NEW.microservice_status := COALESCE(NEW.microservice_status, NEW.sku_status);

        NEW.microservice_description := COALESCE(NEW.microservice_description, NEW.sku_description);

        NEW.microservice_pricing_unit := COALESCE(NEW.microservice_pricing_unit, NEW.sku_pricing_unit);



        NEW.ref_accounts_in_record_id_account_name := COALESCE(NEW.ref_accounts_in_record_id_account_name, NEW.ref_accounts_in_record_id);

        NEW.ref_practice_id := COALESCE(NEW.ref_practice_id, NEW.ref_practices_in_record_id);

        NEW.bill_to_corporate_unit := COALESCE(NEW.bill_to_corporate_unit, NEW.ref_practices_in_record_id_bill_to);

        NEW.bill_to_individual_name := COALESCE(NEW.bill_to_individual_name, NEW.ref_users_in_record_id_bill_to);

        NEW.kpi := COALESCE(NEW.kpi, NEW.ref_kpi_in_record_id);

        NEW.deliverable_db := COALESCE(NEW.deliverable_db, NEW.ref_master_table_in_record_id_deliverable);



        RETURN NEW;

    END IF;



    -- =====================

    -- UPDATE HANDLING

    -- =====================



    -- Forward sync (microservice ΓåÆ sku)

    IF NEW.microservice_name IS DISTINCT FROM OLD.microservice_name THEN

        NEW.sku_name := NEW.microservice_name;

    END IF;



    IF NEW.microservice_type IS DISTINCT FROM OLD.microservice_type THEN

        NEW.sku_type := NEW.microservice_type;

    END IF;



    IF NEW.microservice_status IS DISTINCT FROM OLD.microservice_status THEN

        NEW.sku_status := NEW.microservice_status;

    END IF;



    IF NEW.microservice_description IS DISTINCT FROM OLD.microservice_description THEN

        NEW.sku_description := NEW.microservice_description;

    END IF;



    IF NEW.microservice_pricing_unit IS DISTINCT FROM OLD.microservice_pricing_unit THEN

        NEW.sku_pricing_unit := NEW.microservice_pricing_unit;

    END IF;



    IF NEW.ref_accounts_in_record_id_account_name IS DISTINCT FROM OLD.ref_accounts_in_record_id_account_name THEN

        NEW.ref_accounts_in_record_id := NEW.ref_accounts_in_record_id_account_name;

    END IF;



    IF NEW.ref_practice_id IS DISTINCT FROM OLD.ref_practice_id THEN

        NEW.ref_practices_in_record_id := NEW.ref_practice_id;

    END IF;



    IF NEW.bill_to_corporate_unit IS DISTINCT FROM OLD.bill_to_corporate_unit THEN

        NEW.ref_practices_in_record_id_bill_to := NEW.bill_to_corporate_unit;

    END IF;



    IF NEW.bill_to_individual_name IS DISTINCT FROM OLD.bill_to_individual_name THEN

        NEW.ref_users_in_record_id_bill_to := NEW.bill_to_individual_name;

    END IF;



    IF NEW.kpi IS DISTINCT FROM OLD.kpi THEN

        NEW.ref_kpi_in_record_id := NEW.kpi;

    END IF;



    IF NEW.deliverable_db IS DISTINCT FROM OLD.deliverable_db THEN

        NEW.ref_master_table_in_record_id_deliverable := NEW.deliverable_db;

    END IF;



    -- Reverse sync (sku ΓåÆ microservice)

    IF NEW.sku_name IS DISTINCT FROM OLD.sku_name THEN

        NEW.microservice_name := NEW.sku_name;

    END IF;



    IF NEW.sku_type IS DISTINCT FROM OLD.sku_type THEN

        NEW.microservice_type := NEW.sku_type;

    END IF;



    IF NEW.sku_status IS DISTINCT FROM OLD.sku_status THEN

        NEW.microservice_status := NEW.sku_status;

    END IF;



    IF NEW.sku_description IS DISTINCT FROM OLD.sku_description THEN

        NEW.microservice_description := NEW.sku_description;

    END IF;



    IF NEW.sku_pricing_unit IS DISTINCT FROM OLD.sku_pricing_unit THEN

        NEW.microservice_pricing_unit := NEW.sku_pricing_unit;

    END IF;



    IF NEW.ref_accounts_in_record_id IS DISTINCT FROM OLD.ref_accounts_in_record_id THEN

        NEW.ref_accounts_in_record_id_account_name := NEW.ref_accounts_in_record_id;

    END IF;



    IF NEW.ref_practices_in_record_id IS DISTINCT FROM OLD.ref_practices_in_record_id THEN

        NEW.ref_practice_id := NEW.ref_practices_in_record_id;

    END IF;



    IF NEW.ref_practices_in_record_id_bill_to IS DISTINCT FROM OLD.ref_practices_in_record_id_bill_to THEN

        NEW.bill_to_corporate_unit := NEW.ref_practices_in_record_id_bill_to;

    END IF;



    IF NEW.ref_users_in_record_id_bill_to IS DISTINCT FROM OLD.ref_users_in_record_id_bill_to THEN

        NEW.bill_to_individual_name := NEW.ref_users_in_record_id_bill_to;

    END IF;



    IF NEW.ref_kpi_in_record_id IS DISTINCT FROM OLD.ref_kpi_in_record_id THEN

        NEW.kpi := NEW.ref_kpi_in_record_id;

    END IF;



    IF NEW.ref_master_table_in_record_id_deliverable IS DISTINCT FROM OLD.ref_master_table_in_record_id_deliverable THEN

        NEW.deliverable_db := NEW.ref_master_table_in_record_id_deliverable;

    END IF;



    RETURN NEW;

END;

$function$