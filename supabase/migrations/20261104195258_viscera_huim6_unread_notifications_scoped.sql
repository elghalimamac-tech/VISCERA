
create or replace function public.viscera_unread_notification_count()
returns integer language sql stable set search_path to 'pg_catalog','public'
as $function$
  select count(*)::integer
  from public.viscera_notifications
  where user_id = (select auth.uid())
    and hospital_id = 'huim6'
    and dismissed_at is null
    and read_at is null
$function$;
