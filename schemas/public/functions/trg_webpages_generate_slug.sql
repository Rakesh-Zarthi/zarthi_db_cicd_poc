CREATE OR REPLACE FUNCTION public.trg_webpages_generate_slug()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

    -- Only generate slug when SKU Role is linked

    IF NEW.ref_services_sku_roles_in_record_id IS NOT NULL

       AND NEW.page_name IS NOT NULL

    THEN

        NEW.slug :=

            trim(

                both '-'

                FROM regexp_replace(

                    lower(NEW.page_name),

                    '[^a-z0-9]+',

                    '-',

                    'g'

                )

            );

    END IF;



    RETURN NEW;

END;

$function$