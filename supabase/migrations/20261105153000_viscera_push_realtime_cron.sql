-- Notifications VISCERA : envoi immédiat sur insertion, contrôle toutes les minutes.
-- Aucun secret d'authentification Supabase/Firebase dans SQL, GitHub ou Flutter.
create extension if not exists pg_cron;
create extension if not exists pg_net;
create schema if not exists viscera_private;
revoke all on schema viscera_private from public, anon, authenticated, service_role;

-- Secret HMAC aléatoire et chiffré dans Supabase Vault.
do $seed$
begin
  if not exists (
    select 1 from vault.secrets where name = 'viscera_push_dispatch_signing'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'viscera_push_dispatch_signing',
      'HMAC de réveil interne des notifications VISCERA'
    );
  end if;
end
$seed$;

-- Appelé uniquement par l'Edge Function avec une clé serveur Supabase.
-- Une signature ne reste valide que 5 minutes, sans jamais exposer le secret.
create or replace function public.viscera_verify_push_dispatch(
  p_epoch text,
  p_signature text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $verify$
declare
  signing_key text;
  expected_sig text;
begin
  if p_epoch is null or p_signature is null
     or p_epoch !~ '^[0-9]{10,13}$'
     or p_signature !~ '^[a-f0-9]{64}$'
     or abs(extract(epoch from clock_timestamp()) - p_epoch::numeric) > 300 then
    return false;
  end if;
  select decrypted_secret into signing_key
    from vault.decrypted_secrets
    where name = 'viscera_push_dispatch_signing'
    limit 1;
  if signing_key is null then return false; end if;
  expected_sig := encode(
    extensions.hmac('viscera-push:' || p_epoch, signing_key, 'sha256'),
    'hex'
  );
  return p_signature = expected_sig;
end
$verify$;
revoke all on function public.viscera_verify_push_dispatch(text,text)
  from public, anon, authenticated;
grant execute on function public.viscera_verify_push_dispatch(text,text)
  to service_role;

-- Réveil asynchrone après COMMIT; pas de données de patient dans la requête.
create or replace function viscera_private.dispatch_push_wakeup()
returns void
language plpgsql
security definer
set search_path = ''
as $wakeup$
declare
  stamp text;
  signing_key text;
  sig text;
begin
  stamp := (extract(epoch from clock_timestamp())::bigint)::text;
  select decrypted_secret into signing_key
    from vault.decrypted_secrets
    where name = 'viscera_push_dispatch_signing'
    limit 1;
  if signing_key is null then
    raise exception 'Missing internal notification signing key';
  end if;
  sig := encode(
    extensions.hmac('viscera-push:' || stamp, signing_key, 'sha256'),
    'hex'
  );
  perform net.http_post(
    url := 'https://qkupckqgczdqiwxozxko.supabase.co/functions/v1/viscera-push-dispatch',
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-viscera-epoch', stamp,
      'x-viscera-signature', sig
    ),
    timeout_milliseconds := 10000
  );
end
$wakeup$;
revoke all on function viscera_private.dispatch_push_wakeup()
  from public, anon, authenticated, service_role;

-- Une invocation par INSERT SQL, même si plusieurs destinataires sont insérés.
-- La panne éventuelle du système push ne doit jamais bloquer l'enregistrement.
create or replace function viscera_private.on_notification_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $trigger$
begin
  begin
    perform viscera_private.dispatch_push_wakeup();
  exception when others then
    raise warning 'VISCERA push wakeup unavailable: %', sqlstate;
  end;
  return null;
end
$trigger$;
revoke all on function viscera_private.on_notification_insert()
  from public, anon, authenticated, service_role;

drop trigger if exists viscera_notification_push_wakeup
  on public.viscera_notifications;
create trigger viscera_notification_push_wakeup
after insert on public.viscera_notifications
for each statement execute function viscera_private.on_notification_insert();

-- Rattrapage des échecs et notifications repassées en attente.
do $cron$
begin
  if not exists (
    select 1 from cron.job where jobname = 'viscera-push-dispatch-minute'
  ) then
    perform cron.schedule(
      'viscera-push-dispatch-minute',
      '* * * * *',
      'select viscera_private.dispatch_push_wakeup();'
    );
  end if;
end
$cron$;