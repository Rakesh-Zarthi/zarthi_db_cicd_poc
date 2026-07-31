CREATE OR REPLACE FUNCTION public.validate_duplicate_sub_group()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_owner    bigint;

    v_channel  text;

    v_group_id text;

    v_members  bigint[];

    v_dup_id   bigint;

    v_lock_key bigint;

BEGIN

    ------------------------------------------------------------------

    -- Only Sub Groups

    ------------------------------------------------------------------

    SELECT

        ref_requests_in_record_id_group_owner,

        channel,

        group_id

    INTO

        v_owner,

        v_channel,

        v_group_id

    FROM public.groups

    WHERE in_record_id = NEW.in_record_id

      AND group_type = 'Sub Group';



    IF v_owner IS NULL THEN

        RETURN NEW;

    END IF;



    ------------------------------------------------------------------

    -- ≡ƒöÉ Advisory lock (transaction scoped)

    ------------------------------------------------------------------

    v_lock_key :=

        hashtext(

            v_owner::text || ':' || v_channel || ':' || v_group_id

        );



    PERFORM pg_advisory_xact_lock(v_lock_key);



    ------------------------------------------------------------------

    -- Collect members of THIS group (normalized to bigint[])

    ------------------------------------------------------------------

    SELECT array_agg(

               ref_requests_in_record_id_members::bigint

               ORDER BY ref_requests_in_record_id_members::bigint

           )

    INTO v_members

    FROM public.groups_members

    WHERE ref_groups_in_record_id = NEW.in_record_id;



    ------------------------------------------------------------------

    -- Detect identical subgroup (set comparison)

    ------------------------------------------------------------------

    SELECT g.in_record_id

    INTO v_dup_id

    FROM public.groups g

    JOIN public.groups_members gm

      ON gm.ref_groups_in_record_id = g.in_record_id

    WHERE g.group_type = 'Sub Group'

      AND g.in_record_id <> NEW.in_record_id

      AND g.ref_requests_in_record_id_group_owner = v_owner

      AND g.channel = v_channel

      AND g.group_id = v_group_id

    GROUP BY g.in_record_id

    HAVING

        array_agg(

            gm.ref_requests_in_record_id_members::bigint

            ORDER BY gm.ref_requests_in_record_id_members::bigint

        ) = v_members

    LIMIT 1;



    IF v_dup_id IS NOT NULL THEN

        RAISE EXCEPTION

            'Duplicate Sub Group detected. Group % has identical members as group %',

            NEW.in_record_id,

            v_dup_id;

    END IF;



    RETURN NEW;

END;

$function$