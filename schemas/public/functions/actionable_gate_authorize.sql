CREATE OR REPLACE FUNCTION public.actionable_gate_authorize()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

DECLARE

    v_request_id BIGINT;

    v_fk_value   BIGINT;

BEGIN

    -- Extract FK value from NEW

    v_fk_value := public.csn_get_new_fk_value(NEW, TG_ARGV[1]);



    -- Resolve request via explicit request column

    v_request_id :=

        public.resolve_request_from_fk(

            TG_ARGV[0],  -- owning table

            TG_ARGV[1],  -- request_id column

            v_fk_value

        );



    -- Authorize

    PERFORM public.csn_require_completed_actionable(

        v_request_id,

        TG_ARGV[2],

        TG_ARGV[3]

    );



    RETURN NEW;

END;

$function$