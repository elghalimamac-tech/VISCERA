-- Les administrateurs approuvés peuvent consulter les comptes et valider des médecins.
-- La suppression, les mots de passe et la nomination des admins restent propriétaire uniquement.
alter table viscera_private.doctor_approval_audit drop constraint if exists doctor_approval_audit_target_id_fkey;
alter table viscera_private.doctor_approval_audit add constraint doctor_approval_audit_target_id_fkey foreign key(target_id) references auth.users(id) on delete cascade;
alter table viscera_private.doctor_approval_audit drop constraint if exists doctor_approval_audit_actor_id_fkey;
alter table viscera_private.doctor_approval_audit add constraint doctor_approval_audit_actor_id_fkey foreign key(actor_id) references auth.users(id) on delete cascade;
create or replace function public.viscera_admin_all_users()
returns table(user_id uuid,display_name text,first_name text,last_name text,
 requested_role text,approved_role text,approval_status text,junior_category text,
 internship_passage smallint,senior_title text,is_admin boolean,
 created_at timestamptz,email text,is_owner boolean)
language sql stable security definer set search_path='' as $$
select u.id,
 coalesce(p.display_name,nullif(trim(concat_ws(' ',
  u.raw_user_meta_data->>'first_name',u.raw_user_meta_data->>'last_name')),''),
  'Compte sans profil')::text,
 p.first_name,p.last_name,p.requested_role,p.approved_role,
 coalesce(p.approval_status,'orphan')::text,p.junior_category,p.internship_passage,
 p.senior_title,coalesce(p.is_admin,false),u.created_at,u.email::text,
 (u.id='4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid)
from auth.users u left join public.doctor_profiles p on p.user_id=u.id
where exists(select 1 from public.doctor_profiles actor
 where actor.user_id=(select auth.uid()) and actor.is_admin=true
 and actor.approval_status='approved' and actor.approved_role in ('junior','senior'))
order by case when p.approval_status='pending' then 0 else 1 end,u.created_at desc;
$$;
revoke all on function public.viscera_admin_all_users() from public,anon,authenticated;
grant execute on function public.viscera_admin_all_users() to authenticated;
create or replace function public.viscera_admin_review_doctor(p_target uuid,p_action text)
returns void language plpgsql security definer set search_path='' as $$
declare v_role text; v_admin boolean;
begin
 if not exists(select 1 from public.doctor_profiles actor
 where actor.user_id=(select auth.uid()) and actor.is_admin=true
 and actor.approval_status='approved' and actor.approved_role in ('junior','senior'))
 then raise exception 'Accès administrateur nécessaire' using errcode='42501'; end if;
 if p_target is null or p_target=(select auth.uid())
  or p_target='4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid
  or p_action is null or p_action not in ('approve','disable','pending')
 then raise exception 'Opération interdite ou inconnue' using errcode='42501'; end if;
 select requested_role,is_admin into v_role,v_admin
 from public.doctor_profiles where user_id=p_target for update;
 if not found or coalesce(v_admin,false) then
 raise exception 'Compte introuvable ou administrateur protégé' using errcode='42501'; end if;
 if v_role not in ('junior','senior') then
 raise exception 'Rôle médical non reconnu' using errcode='22023'; end if;
 update public.doctor_profiles set approval_status=
 case when p_action='approve' then 'approved' when p_action='disable'
 then 'disabled' else 'pending' end,
 approved_role=case when p_action='approve' then v_role else null end,
 reviewed_at=now() where user_id=p_target and is_admin=false;
 insert into viscera_private.doctor_approval_audit(actor_id,target_id,operation)
 values ((select auth.uid()),p_target,p_action);
end;
$$;
revoke all on function public.viscera_admin_review_doctor(uuid,text) from public,anon,authenticated;
grant execute on function public.viscera_admin_review_doctor(uuid,text) to authenticated;
