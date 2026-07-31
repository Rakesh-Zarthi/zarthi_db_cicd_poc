CREATE OR REPLACE FUNCTION public.game_get_user_answers(p_user_id bigint)
 RETURNS jsonb[]
 LANGUAGE sql
 STABLE
AS $function$

    SELECT COALESCE(

        ARRAY_AGG(a.user_answer::JSONB ORDER BY a.answered_at),

        ARRAY[]::JSONB[]

    )

    FROM public.answer_table a

    WHERE a.ref_website_user_in_record_id = p_user_id;

$function$