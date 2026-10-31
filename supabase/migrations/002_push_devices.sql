-- VISCERA ONLY — schema des jetons push. Aucun droit d'envoi client.
-- Exécuter après 001_doctor_profiles.sql dans le NOUVEAU projet VISCERA.
create table if not exists public.push_devices (
  token text primary key check (char_length(token) between 16 and 4096),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android','ios')),
  updated_at timestamptz not null default now()
);
create index if not exists push_devices_owner on public.push_devices(user_id);
alter table public.push_devices enable row level security;
revoke all on public.push_devices from anon;
revoke all on public.push_devices from authenticated;
grant select, insert, update, delete on public.push_devices to authenticated;

create policy push_devices_read_self on public.push_devices for select to authenticated
using (user_id = (select auth.uid()));
create policy push_devices_create_self on public.push_devices for insert to authenticated
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.doctor_profiles p
  where p.user_id = (select auth.uid()) and p.approval_status = 'approved'
));
create policy push_devices_update_self on public.push_devices for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.doctor_profiles p
  where p.user_id = (select auth.uid()) and p.approval_status = 'approved'
));
create policy push_devices_delete_self on public.push_devices for delete to authenticated
using (user_id = (select auth.uid()));
-- Important : le serveur FCM HTTP v1 doit être appelé depuis une fonction privée
-- authentifiée par une clé Google et jamais depuis l'application mobile.
