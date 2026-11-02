-- VISCERA: préférences et événement de réévaluation de sortie.
-- Aucun patient n'est automatiquement sorti ; aucun identifiant clinique dans FCM.
alter table public.viscera_notification_preferences
  add column if not exists discharge_review boolean not null default true;

alter table public.viscera_notifications
  drop constraint if exists viscera_notifications_kind_check;
alter table public.viscera_notifications
  add constraint viscera_notifications_kind_check
  check (kind in ('program_updates','urgent_admissions','access_updates','discharge_review'));

-- Tables déjà protégées par RLS ; les droits actuels restent inchangés.
