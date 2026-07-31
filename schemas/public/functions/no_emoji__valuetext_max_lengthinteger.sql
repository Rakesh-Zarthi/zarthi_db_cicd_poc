CREATE OR REPLACE FUNCTION public.no_emoji(value text, max_length integer DEFAULT 250)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$

DECLARE

  cleaned text;

BEGIN

  -- 1. Handle NULL

  IF value IS NULL THEN

    RETURN TRUE;

  END IF;



  -- 2. Trim spaces

  cleaned := trim(value);



  -- 3. Reject empty or space-only strings

  IF char_length(cleaned) = 0 THEN

    RETURN FALSE;

  END IF;



  -- 4. Enforce max length

  IF char_length(cleaned) > max_length THEN

    RETURN FALSE;

  END IF;



  -- 5. Block emojis using Expanded Unicode ranges

  -- Added:

  -- \uFE00-\uFE0F (Variation Selectors - THE CULPRIT)

  -- \u20E3       (Keycap symbol, used for 1∩╕ÅΓâú, 2∩╕ÅΓâú etc)

  -- \uFFFD       (The Replacement Character  - often appears as a block in corrupt data)

  IF cleaned ~* '[\u2600-\u27BF\uFE00-\uFE0F\u20E3\uFFFD\U0001F000-\U0001FFFF]' THEN

    RETURN FALSE;

  END IF;



  RETURN TRUE;

END;

$function$