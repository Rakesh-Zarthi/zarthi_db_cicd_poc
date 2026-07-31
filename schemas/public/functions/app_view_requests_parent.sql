CREATE OR REPLACE FUNCTION public.app_view_requests_parent()
 RETURNS TABLE(id record_id, root_parent record_id, immediate_parent record_id, immediate_module single_line_text, root_owner single_line_text, root_account single_line_text, immediate_owner_id record_id, immediate_owner single_line_text, immediate_owner_email email_address, immediate_account_id record_id, immediate_account single_line_text, root_parent_request_subject single_line_text, immediate_parent_request_subject single_line_text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$

	BEGIN



		PERFORM set_config(

			'app.CURRENT_APP_ID',

			'9f4c8a7b6e2d1c3a5b8f0d9e7c6a4b2f1e3d5c7a9b0e2f4c6d8a1b3c5e7f9d0',

			true

		);



		RETURN QUERY

		SELECT



			r1.in_record_id::record_id,



			COALESCE(

				s1.root_parent,

				st1.root_parent,

				rsr.root_parent

			)::record_id,



			COALESCE(

				s1.immediate_parent,

				st1.immediate_parent,

				rsr.immediate_parent

			)::record_id,



			COALESCE(

				r2.module,

				r2_staff.module,

				r2_role.module

			)::single_line_text,



			COALESCE(

				u4.user_name,

				u5.user_name,

				u6.user_name

			)::single_line_text,



			COALESCE(

				u4.account_name,

				u5.account_name,

				u6.account_name

			)::single_line_text,



			COALESCE(

				u2.id,

				u3.id,

				u7.id,

				u1.id

			)::record_id,



			COALESCE(

				u2.user_name,

				u3.user_name,

				u7.user_name,

				u1.user_name

			)::single_line_text,



			COALESCE(

				u2.email_id,

				u3.email_id,

				u7.email_id,

				u1.email_id

			)::email_address,



			COALESCE(

				u2.account_id,

				u3.account_id,

				u7.account_id,

				u1.account_id

			)::record_id,



			COALESCE(

				u2.account_name,

				u3.account_name,

				u7.account_name,

				u1.account_name

			)::single_line_text,



			COALESCE(

				r3.summary,

				r3_staff.summary,

				r3_role.summary

			)::single_line_text,



			COALESCE(

				r2.summary,

				r2_staff.summary,

				r2_role.summary

			)::single_line_text



		FROM requests r1



		LEFT JOIN requests_services s1

			ON s1.ref_requests_record_id = r1.in_record_id



		LEFT JOIN requests_staffing st1

			ON st1.ref_requests_record_id = r1.in_record_id



		LEFT JOIN requests_sku_roles rsr

			ON rsr.ref_requests_in_record_id = r1.in_record_id



		-- Services hierarchy

		LEFT JOIN requests r2

			ON r2.in_record_id = s1.immediate_parent



		LEFT JOIN users_universal u2

			ON u2.id = r2.owner



		LEFT JOIN requests r3

			ON r3.in_record_id = s1.root_parent



		LEFT JOIN users_universal u4

			ON u4.id = r3.owner



		-- Staffing hierarchy

		LEFT JOIN requests r2_staff

			ON r2_staff.in_record_id = st1.immediate_parent



		LEFT JOIN users_universal u3

			ON u3.id = r2_staff.owner



		LEFT JOIN requests r3_staff

			ON r3_staff.in_record_id = st1.root_parent



		LEFT JOIN users_universal u5

			ON u5.id = r3_staff.owner



		-- Roles hierarchy

		LEFT JOIN requests r2_role

			ON r2_role.in_record_id = rsr.immediate_parent



		LEFT JOIN users_universal u7

			ON u7.id = r2_role.owner



		LEFT JOIN requests r3_role

			ON r3_role.in_record_id = rsr.root_parent



		LEFT JOIN users_universal u6

			ON u6.id = r3_role.owner



		-- Current request owner

		LEFT JOIN users_universal u1

			ON u1.id = r1.owner;



	END;

	$function$