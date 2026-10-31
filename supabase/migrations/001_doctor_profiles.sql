-- VISCERA V12 — à appliquer UNIQUEMENT au projet Supabase VISCERA.
-- Ne pas exécuter sur PlanningHM6 ou GardeFlow.
-- Ce schéma autorise la lecture du profil de l'utilisateur seulement.
-- Il n'autorise PAS l'accès aux patients, gardes ou documents cliniques.

create table if not exists public.doctor_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null check (char_length(display_name) between 3 and 160),
    requested_role text not null check (requested_role in ('junior', 'senior')),
    approved_role text null check (approved_role in ('junior', 'senior')),
    approval_status text not null default 'pending'
      check (approval_status in ('pending', 'approved', 'disabled')),
    created_at timestamptz not null default now(),
    reviewed_at timestamptz,
    constraint approved_must_have_role check (
        approval_status <> 'approved' or approved_role is not null
    )
);

alter table public.doctor_profiles enable row level security;
revoke all on public.doctor_profiles from anon;
revoke all on public.doctor_profiles from authenticated;
grant select on public.doctor_profiles to authenticated;

drop policy if exists doctor_profiles_self_read on public.doctor_profiles;
create policy doctor_profiles_self_read on public.doctor_profiles
for select to authenticated using (user_id = (select auth.uid()));

-- Aucun INSERT/UPDATE/DELETE client. L'approbation reste administrative.
-- auth.users est géré par Supabase Auth ; déclencheur privé non exposé à l'API.
create schema if not exists viscera_private;
revoke all on schema viscera_private from public, anon, authenticated;

create or replace function viscera_private.register_doctor_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    submitted_name text;
    submitted_role text;
begin
    submitted_name := trim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
    submitted_role := coalesce(new.raw_user_meta_data ->> 'requested_role', '');
    if char_length(submitted_name) < 3 or char_length(submitted_name) > 160 then
        submitted_name := 'Médecin en attente';
    end if;
    if submitted_role not in ('junior','senior') then
        submitted_role := 'junior';
    end if;
    insert into public.doctor_profiles (user_id, display_name, requested_role)
    values (new.id, submitted_name, submitted_role)
    on conflict (user_id) do nothing;
    return new;
end;
$$;

revoke all on function viscera_private.register_doctor_profile()
from public, anon, authenticated;

drop trigger if exists viscera_auth_user_created on auth.users;
create trigger viscera_auth_user_created
    after insert on auth.users
    for each row execute function viscera_private.register_doctor_profile();

-- Pour approuver un médecin : après contrôle réel de sa qualité et de son email,
-- un administrateur DB exécute dans SQL Editor Supabase avec son UUID :
-- update public.doctor_profiles
-- set approved_role='junior', approval_status='approved', reviewed_at=now()
-- where user_id='UUID-DU-MEDECIN-VERIFIE';
-- Pour révoquer : update ... set approval_status='disabled' where user_id=...;
