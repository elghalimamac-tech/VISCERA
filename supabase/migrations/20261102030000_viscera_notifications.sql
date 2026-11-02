-- VISCERA — notifications génériques sans données cliniques.
create table if not exists public.viscera_notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  program_updates boolean not null default true,
  urgent_admissions boolean not null default true,
  access_updates boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.viscera_notification_preferences enable row level security;
grant select, insert, update, delete on public.viscera_notification_preferences to authenticated;
create table if not exists public.viscera_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('program_updates','urgent_admissions','access_updates')),
  event_key text not null,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  dispatch_status text not null default 'pending'
    check (dispatch_status in ('pending','sending','sent','waiting_device','retry','failed')),
  delivered_at timestamptz,
  attempts int not null default 0,
  next_attempt_at timestamptz not null default now(),
  unique(user_id,event_key)
);
create index if not exists viscera_notifications_dispatch on public.viscera_notifications(dispatch_status,next_attempt_at,created_at)
 where dispatch_status in ('pending','retry','waiting_device');
create index if not exists viscera_notifications_user_created on public.viscera_notifications(user_id,created_at desc);
alter table public.viscera_notifications enable row level security;
revoke all on public.viscera_notifications from anon, authenticated;
grant select on public.viscera_notifications to authenticated;
grant update(read_at) on public.viscera_notifications to authenticated;

do $migration$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='viscera_notification_preferences' and policyname='viscera_notification_preferences_own_select') then
    create policy viscera_notification_preferences_own_select on public.viscera_notification_preferences for select to authenticated using (user_id = (select auth.uid()));
  end if;
end $migration$;
do $migration$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='viscera_notification_preferences' and policyname='viscera_notification_preferences_own_insert') then
    create policy viscera_notification_preferences_own_insert on public.viscera_notification_preferences for insert to authenticated with check (user_id = (select auth.uid()));
  end if;
end $migration$;
do $migration$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='viscera_notification_preferences' and policyname='viscera_notification_preferences_own_update') then
    create policy viscera_notification_preferences_own_update on public.viscera_notification_preferences for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
  end if;
end $migration$;
do $migration$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='viscera_notifications' and policyname='viscera_notifications_self_read') then
    create policy viscera_notifications_self_read on public.viscera_notifications for select to authenticated using (user_id = (select auth.uid()));
  end if;
end $migration$;
do $migration$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='viscera_notifications' and policyname='viscera_notifications_self_mark_read') then
    create policy viscera_notifications_self_mark_read on public.viscera_notifications for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
  end if;
end $migration$;

CREATE OR REPLACE FUNCTION public.viscera_queue_staff_notifications()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if tg_table_name='bloc_program_imports' then
    if new.is_current is true
       and (tg_op = 'INSERT' or old.is_current is distinct from true) then
      insert into public.viscera_notifications(user_id,kind,event_key,title,body)
        select p.user_id,'program_updates', 'bloc:'||new.id::text,
               'VISCERA · Programme opératoire',
               'Un nouveau programme opératoire est disponible dans VISCERA.'
        from public.doctor_profiles p
        left join public.viscera_notification_preferences pref on pref.user_id = p.user_id
        where p.approval_status='approved' and p.approved_role in ('junior','senior')
          and coalesce(pref.program_updates,true)
        on conflict(user_id,event_key) do nothing;
    end if;
  elsif tg_table_name='manual_patient_records' then
    if lower(coalesce(new.origin,'')) like 'urgenc%'
       or lower(coalesce(new.block_timing,'')) in ('immédiat','immediat') then
      insert into public.viscera_notifications(user_id,kind,event_key,title,body)
        select p.user_id,'urgent_admissions','urgent:'||new.id::text,
               'VISCERA · Admission urgente',
               'Une admission urgente nécessite une vérification dans VISCERA.'
        from public.doctor_profiles p
        left join public.viscera_notification_preferences pref on pref.user_id=p.user_id
        where p.approval_status='approved' and p.approved_role='senior'
          and p.user_id is distinct from new.created_by
          and coalesce(pref.urgent_admissions,true)
        on conflict(user_id,event_key) do nothing;
    end if;
  elsif tg_table_name='doctor_profiles' then
    if tg_op = 'INSERT' and new.approval_status='pending' then
      insert into public.viscera_notifications(user_id,kind,event_key,title,body)
        select p.user_id,'access_updates','approval:request:'||new.user_id::text,
               'VISCERA · Validation demandée',
               'Une demande de compte médical attend votre vérification.'
        from public.doctor_profiles p
        left join public.viscera_notification_preferences pref on pref.user_id=p.user_id
        where p.is_admin is true and p.approval_status='approved'
          and coalesce(pref.access_updates,true)
        on conflict(user_id,event_key) do nothing;
    elsif tg_op='UPDATE' and new.approval_status is distinct from old.approval_status
       and new.approval_status in ('approved','rejected','disabled') then
      insert into public.viscera_notifications(user_id,kind,event_key,title,body)
      select new.user_id,'access_updates',
             'approval:status:'||new.user_id::text||':'||new.approval_status,
             'VISCERA · Statut de votre compte',
             case when new.approval_status='approved'
               then 'Votre accès au service est maintenant validé.'
               else 'Le statut de votre compte a changé. Consultez VISCERA.' end
      where coalesce((select pref.access_updates
                      from public.viscera_notification_preferences pref
                      where pref.user_id=new.user_id),true)
      on conflict(user_id,event_key) do nothing;
    end if;
  end if;
  return new;
end;
$function$
;
revoke all on function public.viscera_queue_staff_notifications() from public, anon, authenticated;
drop trigger if exists viscera_push_program on public.bloc_program_imports;
CREATE TRIGGER viscera_push_program AFTER INSERT OR UPDATE OF is_current ON public.bloc_program_imports FOR EACH ROW EXECUTE FUNCTION viscera_queue_staff_notifications();
drop trigger if exists viscera_push_urgent on public.manual_patient_records;
CREATE TRIGGER viscera_push_urgent AFTER INSERT ON public.manual_patient_records FOR EACH ROW EXECUTE FUNCTION viscera_queue_staff_notifications();
drop trigger if exists viscera_push_account on public.doctor_profiles;
CREATE TRIGGER viscera_push_account AFTER INSERT OR UPDATE OF approval_status ON public.doctor_profiles FOR EACH ROW EXECUTE FUNCTION viscera_queue_staff_notifications();
