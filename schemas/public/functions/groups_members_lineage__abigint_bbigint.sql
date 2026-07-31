CREATE OR REPLACE FUNCTION public.groups_members_lineage(a bigint, b bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$

    SELECT EXISTS (

        SELECT 1

        FROM public.requests_hierarchy ra

        JOIN public.requests_hierarchy rb

          ON ra.root_parent = rb.root_parent

        WHERE ra.request_id = a

          AND rb.request_id = b

          AND (

                a = b

             OR a = ANY (rb.full_path)   -- a is ancestor of b

             OR b = ANY (ra.full_path)   -- b is ancestor of a

          )

    );

$function$