-- Sans confirmation mail, le propriétaire doit pouvoir vérifier l'adresse
-- déclarée par un canal professionnel indépendant avant d'approuver.
create or replace function public.viscera_admin_get_doctors_with_email()
returns table (
 user_id uuid, display_name text, first_name text, last_name text,
 requested_role text, approved_role text, approval_status text,
 junior_category text, internship_passage smallint, senior_title text,
 is_admin boolean, created_at timestamptz, email text
)
language sql stable security definer set search_path = ''
as $$
 select p.user_id,p.display_name,p.first_name,p.last_name,
        p.requested_role,p.approved_role,p.approval_status,
        p.junior_category,p.internship_passage,p.senior_title,
        p.is_admin,p.created_at,u.email::text
 from public.doctor_profiles p
 join auth.users u on u.id=p.user_id
 where exists (
   select 1 from public.doctor_profiles owner
   where owner.user_id=(select auth.uid())
     and owner.user_id='4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid
     and owner.is_admin=true and owner.approval_status='approved'
     and owner.approved_role in ('junior','senior')
 )
 order by case when p.approval_status='pending' then 0 else 1 end,
          p.created_at desc;
$$;
revoke all on function public.viscera_admin_get_doctors_with_email()
 from public,anon,authenticated;
grant execute on function public.viscera_admin_get_doctors_with_email()
 to authenticated;
