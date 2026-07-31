CREATE OR REPLACE FUNCTION public.apply_sku_access_to_master_user(p_master_table_id bigint, p_user_uuid uuid, p_permission text, p_delta integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

BEGIN

    UPDATE public.master_key mk

    SET master_user =

        jsonb_set(

            COALESCE(mk.master_user, '{}'::jsonb),

            ARRAY[p_permission, p_user_uuid::text],

            to_jsonb(

                COALESCE(

                    (mk.master_user -> p_permission ->> p_user_uuid::text)::int,

                    0

                ) + p_delta

            ),

            true

        )

    WHERE mk.in_ref_master_table = p_master_table_id;

END;

$function$