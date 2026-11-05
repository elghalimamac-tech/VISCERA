-- VISCERA: modification contrôlée du grade junior par un ADMIN approuvé.
-- Catégories identiques au formulaire d'inscription. Audit en schéma privé.
create table if not exists viscera_private.doctor_grade_audit (
  audit_id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references auth.users(id) on delete cascade,
  old_junior_category text,
  old_internship_passage smallint,
  new_junior_category text not null,
  new_internship_passage smallint,
  changed_at timestamptz not null default now()
);
alter table viscera_private.doctor_grade_audit enable row level security;
revoke all on viscera_private.doctor_grade_audit from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.viscera_admin_update_junior_grade(p_target uuid, p_category text, p_passage integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_old_category text;
  v_old_passage smallint;
  v_target_admin boolean;
  v_requested_role text;
  v_approved_role text;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.doctor_profiles actor
    where actor.user_id=(select auth.uid())
      and actor.is_admin=true
      and actor.approval_status='approved'
      and actor.approved_role in ('junior','senior')
  ) then
    raise exception 'Permission ADMIN nécessaire' using errcode='42501';
  end if;
  if p_target is null or p_target=(select auth.uid())
     or p_target='4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid then
    raise exception 'Compte protégé' using errcode='42501';
  end if;
  if p_category is null or p_category not in (
    'interne_1','interne_2','resident_1','resident_2',
    'resident_3','resident_4','resident_5'
  ) then
    raise exception 'Catégorie junior incorrecte' using errcode='22023';
  end if;
  if (p_category='interne_1' and (p_passage is null or p_passage not in (1,2)))
    or (p_category='interne_2' and (p_passage is null or p_passage not in (3,4)))
    or (p_category like 'resident_%' and p_passage is not null) then
    raise exception 'Passage d’internat incompatible avec le grade' using errcode='22023';
  end if;

  select p.requested_role,p.approved_role,p.is_admin,
         p.junior_category,p.internship_passage
  into v_requested_role,v_approved_role,v_target_admin,
       v_old_category,v_old_passage
  from public.doctor_profiles p where p.user_id=p_target for update;

  if not found or v_requested_role<>'junior' or
     (v_approved_role is not null and v_approved_role<>'junior') then
    raise exception 'Compte junior introuvable' using errcode='22023';
  end if;
  if v_target_admin and (select auth.uid()) is distinct from
       '4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid then
    raise exception 'La modification d’un administrateur est réservée au propriétaire'
      using errcode='42501';
  end if;

  if v_old_category is not distinct from p_category
     and v_old_passage is not distinct from p_passage then
    return;
  end if;

  update public.doctor_profiles
     set junior_category=p_category, internship_passage=p_passage::smallint
     where user_id=p_target;
  insert into viscera_private.doctor_grade_audit
    (actor_id,target_id,old_junior_category,old_internship_passage,
     new_junior_category,new_internship_passage)
    values ((select auth.uid()),p_target,v_old_category,v_old_passage,
            p_category,p_passage::smallint);
end;
$function$;
revoke all on function public.viscera_admin_update_junior_grade(uuid,text,integer)
  from public,anon,authenticated;
grant execute on function public.viscera_admin_update_junior_grade(uuid,text,integer)
  to authenticated;
