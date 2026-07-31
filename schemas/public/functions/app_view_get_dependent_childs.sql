CREATE OR REPLACE FUNCTION public.app_view_get_dependent_childs()
 RETURNS TABLE(immediate_parent bigint, dependent_requests bigint, closed_dependent_requests bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

		SELECT

			parent.immediate_parent::bigint,

			COUNT(*) AS dependent_requests,

			COUNT(*) FILTER (WHERE r_child.status = 'Close') AS closed_dependent_requests

		FROM (

			SELECT

				immediate_parent,

				ref_requests_record_id

			FROM requests_services



			UNION ALL



			SELECT

				immediate_parent,

				ref_requests_record_id

			FROM requests_staffing



			UNION ALL



			SELECT

				immediate_parent,

				ref_requests_in_record_id AS ref_requests_record_id

			FROM requests_sku_roles

		) parent

		JOIN requests r_child

			ON r_child.in_record_id = parent.ref_requests_record_id::bigint

		GROUP BY parent.immediate_parent;

	$function$