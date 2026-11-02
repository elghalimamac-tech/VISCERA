-- Archive personnelle des notifications : aucune suppression de dossier patient.
-- Le message reste auditable en base et ne réapparaît pas après reconnexion.
alter table public.viscera_notifications
  add column if not exists dismissed_at timestamptz;

-- Les médecins peuvent seulement lire leurs alertes et changer read_at/dismissed_at.
-- Les destinataires, types, titres, corps et statuts d'envoi restent non modifiables.
grant select on public.viscera_notifications to authenticated;
grant update(dismissed_at) on public.viscera_notifications to authenticated;

-- La table dispose déjà de politiques SELECT/UPDATE RLS limitées à auth.uid().
alter table public.viscera_notifications enable row level security;

create index if not exists viscera_notification_visible_by_user
  on public.viscera_notifications(user_id, created_at desc)
  where dismissed_at is null;

create index if not exists viscera_notification_unread_by_user
  on public.viscera_notifications(user_id)
  where dismissed_at is null and read_at is null;

create or replace function public.viscera_unread_notification_count()
returns integer
language sql stable security invoker
set search_path = pg_catalog, public
as $$
  select count(*)::integer
  from public.viscera_notifications
  where user_id = (select auth.uid())
    and dismissed_at is null
    and read_at is null
$$;

revoke all on function public.viscera_unread_notification_count() from public, anon;
grant execute on function public.viscera_unread_notification_count() to authenticated;
