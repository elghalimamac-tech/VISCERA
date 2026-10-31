-- VISCERA, installation de l'administration propriétaire unique.
alter table public.doctor_profiles add column if not exists is_admin boolean not null default false;
create schema if not exists viscera_private;
create table if not exists viscera_private.doctor_approval_audit (
  audit_id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id),
  target_id uuid not null references auth.users(id),
  operation text not null check(operation in ('approve','disable','pending')),
  performed_at timestamptz not null default now()
);
revoke all on schema viscera_private from public,anon,authenticated;
revoke all on viscera_private.doctor_approval_audit from public,anon,authenticated;
CREATE OR REPLACE FUNCTION public.viscera_admin_get_doctors()
 RETURNS TABLE(user_id uuid, display_name text, first_name text, last_name text, requested_role text, approved_role text, approval_status text, junior_category text, internship_passage smallint, senior_title text, is_admin boolean, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select p.user_id, p.display_name, p.first_name, p.last_name,
         p.requested_role, p.approved_role, p.approval_status,
         p.junior_category, p.internship_passage, p.senior_title,
         p.is_admin, p.created_at
  from public.doctor_profiles p
  where exists (
    select 1 from public.doctor_profiles owner
    where owner.user_id = (select auth.uid())
      and owner.user_id = '4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid
      and owner.is_admin = true
      and owner.approval_status = 'approved'
      and owner.approved_role is not null
  )
  order by case when p.approval_status = 'pending' then 0 else 1 end, p.created_at desc;
$function$
;
revoke all on function public.viscera_admin_get_doctors() from public,anon,authenticated;
grant execute on function public.viscera_admin_get_doctors() to authenticated;
CREATE OR REPLACE FUNCTION public.viscera_admin_review_doctor(p_target uuid, p_action text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_admin boolean;
begin
  if (select auth.uid()) is distinct from '4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid
    or not exists (
      select 1 from public.doctor_profiles own
      where own.user_id = (select auth.uid())
        and own.is_admin = true
        and own.approval_status = 'approved'
        and own.approved_role is not null
    )
  then
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

  select p.requested_role, p.is_admin
  into v_role, v_admin
  from public.doctor_profiles p
  where p.user_id = p_target
  for update;

  if not found or coalesce(v_admin,false) then
    raise exception 'Compte introuvable ou protégé' using errcode = '42501';
  end if;

  if p_action = 'approve' and not exists (
    select 1 from auth.users u
    where u.id = p_target and u.email_confirmed_at is not null
  ) then
    raise exception 'Adresse e-mail non confirmée' using errcode = '23514';
  end if;

  update public.doctor_profiles p
  set approval_status = case
        when p_action = 'approve' then 'approved'
        when p_action = 'disable' then 'disabled'
        else 'pending'
      end,
      approved_role = case when p_action = 'approve' then v_role else null end,
      reviewed_at = now()
  where p.user_id = p_target and p.is_admin = false;

  insert into viscera_private.doctor_approval_audit (actor_id,target_id,operation)
  values ((select auth.uid()), p_target, p_action);
end;
$function$
;
revoke all on function public.viscera_admin_review_doctor(uuid,text) from public,anon,authenticated;
grant execute on function public.viscera_admin_review_doctor(uuid,text) to authenticated;
