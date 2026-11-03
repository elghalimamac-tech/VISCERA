-- VISCERA : notification de sortie confirmée, avec le nom du praticien
-- authentifié. Aucune donnée de patient n'est mise dans les notifications
-- (elles peuvent être relayées vers l'écran verrouillé par Firebase).
-- Idempotent : une alerte par séjour ET par destinataire, jamais de replay
-- lors d'une mise à jour ultérieure du dossier archivé.

alter table public.viscera_notification_preferences
  add column if not exists discharge_confirmed boolean not null default true;

alter table public.viscera_notifications
  drop constraint if exists viscera_notifications_kind_check;
alter table public.viscera_notifications
  add constraint viscera_notifications_kind_check
  check (kind in (
    'program_updates', 'urgent_admissions', 'access_updates',
    'discharge_review', 'discharge_confirmed'
  ));

create or replace function viscera_private.notify_confirmed_discharge()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_author_name text;
  v_event_key text;
begin
  -- Uniquement une PREMIÈRE sortie réellement enregistrée par le serveur.
  if new.clinical_data->>'stage' is distinct from 'discharged'
     or new.clinical_data->>'dischargeAt' is null then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if old.clinical_data->>'stage' is not distinct from 'discharged' then
      return new;
    end if;
  end if;

  -- L'identité de l'auteur provient de Supabase Auth, jamais d'un champ
  -- clinique éditable ni de la personne sélectionnée dans l'interface.
  v_actor := (select auth.uid());
  if v_actor is null or new.updated_by is distinct from v_actor then
    return new;
  end if;
  select nullif(btrim(p.display_name), '') into v_author_name
  from public.doctor_profiles as p
  where p.user_id = v_actor
    and p.approval_status = 'approved'
    and p.approved_role in ('junior', 'senior');
  if v_author_name is null then return new; end if;

  if tg_table_name = 'manual_patient_records' then
    v_event_key := 'discharge:manual:' || new.id::text;
  elsif tg_table_name = 'bloc_patient_records' then
    v_event_key := 'discharge:bloc:' || new.entry_id::text;
  else
    return new;
  end if;

  insert into public.viscera_notifications
    (user_id, kind, event_key, title, body)
  select
    recipient.user_id,
    'discharge_confirmed',
    v_event_key,
    'Sortie confirmée',
    'Sortie validée par ' || v_author_name || '. Le dossier est disponible dans Archives.'
  from public.doctor_profiles as recipient
  left join public.viscera_notification_preferences as preference
    on preference.user_id = recipient.user_id
  where recipient.approval_status = 'approved'
    and recipient.approved_role in ('junior', 'senior')
    and coalesce(preference.discharge_confirmed, true)
  on conflict (user_id, event_key) do nothing;

  return new;
exception when others then
  -- Une panne du service de notification ne doit JAMAIS annuler une sortie
  -- médicale qui a satisfait aux contrôles documentaires et cliniques.
  raise warning 'VISCERA: notification de sortie indisponible (SQLSTATE %)', sqlstate;
  return new;
end;
$$;

revoke all on function viscera_private.notify_confirmed_discharge()
  from public, anon, authenticated;

drop trigger if exists viscera_notify_bloc_discharge
  on public.bloc_patient_records;
create trigger viscera_notify_bloc_discharge
after insert or update of clinical_data on public.bloc_patient_records
for each row
execute function viscera_private.notify_confirmed_discharge();

drop trigger if exists viscera_notify_manual_discharge
  on public.manual_patient_records;
create trigger viscera_notify_manual_discharge
after insert or update of clinical_data on public.manual_patient_records
for each row
execute function viscera_private.notify_confirmed_discharge();
