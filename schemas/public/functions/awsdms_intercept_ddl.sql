CREATE OR REPLACE FUNCTION public.awsdms_intercept_ddl()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
  declare _qry text;
BEGIN
  if (tg_tag='CREATE TABLE' or tg_tag='ALTER TABLE' or tg_tag='DROP TABLE' or tg_tag = 'CREATE TABLE AS') then
	    SELECT current_query() into _qry;
	    insert into public.awsdms_ddl_audit
	    values
	    (
	    default,current_timestamp,current_user,cast(TXID_CURRENT()as varchar(16)),tg_tag,0,'',current_schema,_qry
	    );
	    delete from public.awsdms_ddl_audit;
 end if;
END;
$function$