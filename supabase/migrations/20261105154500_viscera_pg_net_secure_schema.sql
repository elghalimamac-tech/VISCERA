-- pg_net was installed before its explicit schema was specified.
-- Re-create it outside public; net.http_request_queue must be empty first.
-- Supabase docs: pg_net is not relocatable with ALTER EXTENSION.
do $queue$
begin
  if exists (select 1 from net.http_request_queue limit 1) then
    raise exception 'Stop: HTTP request queue is not empty';
  end if;
end
$queue$;
drop extension pg_net;
create extension pg_net with schema extensions;