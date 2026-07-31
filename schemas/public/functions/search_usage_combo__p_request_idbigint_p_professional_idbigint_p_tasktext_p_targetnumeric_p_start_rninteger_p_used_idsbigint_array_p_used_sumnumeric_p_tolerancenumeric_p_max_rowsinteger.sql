CREATE OR REPLACE FUNCTION public.search_usage_combo(p_request_id bigint, p_professional_id bigint, p_task text, p_target numeric, p_start_rn integer, p_used_ids bigint[], p_used_sum numeric, p_tolerance numeric DEFAULT 0, p_max_rows integer DEFAULT 10)
 RETURNS bigint[]
 LANGUAGE plpgsql
AS $function$

DECLARE

    rec      RECORD;

    nxt_ids  BIGINT[];

    nxt_sum  numeric;

BEGIN

    IF p_used_sum >= p_target - p_tolerance

       AND p_used_sum <= p_target + p_tolerance

       AND COALESCE(array_length(p_used_ids,1),0) <= p_max_rows

    THEN

        RETURN p_used_ids;

    END IF;



    FOR rec IN

        SELECT in_record_id, quantity, rn

        FROM   public._usage_combo_rows(p_request_id,

                                        p_professional_id,

                                        p_task)

        WHERE  rn >= p_start_rn

          AND  COALESCE(array_length(p_used_ids,1),0) < p_max_rows

          AND  quantity > 0

        ORDER BY rn

    LOOP

        IF p_used_sum + rec.quantity <= p_target + p_tolerance THEN

            nxt_ids := p_used_ids || rec.in_record_id;

            nxt_sum := p_used_sum + rec.quantity;



            nxt_ids := public.search_usage_combo(

                         p_request_id,

                         p_professional_id,

                         p_task,

                         p_target,

                         rec.rn + 1,

                         nxt_ids,

                         nxt_sum,

                         p_tolerance,

                         p_max_rows

                       );



            IF nxt_ids IS NOT NULL THEN

                RETURN nxt_ids;

            END IF;

        END IF;

    END LOOP;



    RETURN NULL;

END;

$function$