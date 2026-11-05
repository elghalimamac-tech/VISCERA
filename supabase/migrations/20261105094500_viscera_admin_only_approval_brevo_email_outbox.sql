-- VISCERA: seule l'approbation administrative ouvre l'accès.
-- Outbox technique: aucun secret Brevo ni donnée de patient n'est stocké.
create table if not exists public.viscera_approval_email_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check(status in ('pending','sending','sent')),
  attempt_count integer not null default 0,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  sent_at timestamptz,
  brevo_message_id text,
  last_error text
);
create index if not exists viscera_approval_email_pending_idx
 on public.viscera_approval_email_jobs(user_id, status, created_at desc);
alter table public.viscera_approval_email_jobs enable row level security;
revoke all on public.viscera_approval_email_jobs from public, anon, authenticated;
grant select, update, insert on public.viscera_approval_email_jobs to service_role;

create or replace function viscera_private.enqueue_approval_email()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.approval_status = 'approved'
     and old.approval_status is distinct from new.approval_status
     and new.is_admin = false then
    insert into public.viscera_approval_email_jobs(user_id)
    values (new.user_id);
  end if;
  return new;
end;
$$;
revoke all on function viscera_private.enqueue_approval_email()
 from public, anon, authenticated;
drop trigger if exists viscera_queue_approval_email on public.doctor_profiles;
create trigger viscera_queue_approval_email
after update of approval_status on public.doctor_profiles
for each row execute function viscera_private.enqueue_approval_email();

create or replace function public.viscera_admin_review_doctor(p_target uuid, p_action text)
returns void language plpgsql security definer set search_path = ''
as $function$
declare
  v_role text;
  v_admin boolean;
begin
  if (select auth.uid()) is distinct from '4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid
    or not exists (
      select 1 from public.doctor_profiles own
      where own.user_id = (select auth.uid())
        and own.is_admin = true and own.approval_status = 'approved'
        and own.approved_role in ('junior','senior')
    ) then
    raise exception 'Accès administrateur réservé au propriétaire de VISCERA'
      using errcode = '42501';
  end if;
  if p_target is null or p_target = (select auth.uid()) then
    raise exception 'Le compte administrateur ne peut pas être modifié'
      using errcode = '42501';
  end if;
  if p_action is null or p_action not in ('approve','disable','pending') then
    raise exception 'Opération inconnue' using errcode = '22023';
  end if;
  select p.requested_role, p.is_admin into v_role, v_admin
    from public.doctor_profiles p where p.user_id=p_target for update;
  if not found or coalesce(v_admin,false) then
    raise exception 'Compte introuvable ou protégé' using errcode='42501';
  end if;
  if v_role not in ('junior','senior') then
    raise exception 'Rôle médical non reconnu' using errcode='22023';
  end if;
  update public.doctor_profiles p
  set approval_status = case
       when p_action='approve' then 'approved'
       when p_action='disable' then 'disabled'
       else 'pending' end,
      approved_role = case when p_action='approve' then v_role else null end,
      reviewed_at = now()
  where p.user_id=p_target and p.is_admin=false;
  insert into viscera_private.doctor_approval_audit(actor_id,target_id,operation)
    values ((select auth.uid()),p_target,p_action);
end;
$function$;
revoke all on function public.viscera_admin_review_doctor(uuid,text)
  from public,anon,authenticated;
grant execute on function public.viscera_admin_review_doctor(uuid,text)
  to authenticated;
