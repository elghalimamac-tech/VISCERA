
-- Phase 1: HUIM6 data is retained in place; HUICK remains in maintenance.
create table if not exists public.viscera_hospitals (
  id text primary key check (id in ('huim6','huick')),
  name text not null,
  city text not null,
  status text not null check(status in ('active','maintenance')),
  created_at timestamptz not null default now()
);
insert into public.viscera_hospitals(id,name,city,status) values
 ('huim6','HUIM6 Bouskoura','Bouskoura','active'),
 ('huick','HUICK Casablanca','Casablanca','maintenance')
on conflict(id) do nothing;
alter table public.viscera_hospitals enable row level security;
grant select on public.viscera_hospitals to authenticated;
create policy viscera_hospitals_authenticated_read on public.viscera_hospitals
 for select to authenticated using (true);

create table if not exists public.doctor_hospital_memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  hospital_id text not null references public.viscera_hospitals(id),
  member_role text not null check(member_role in ('junior','senior')),
  status text not null default 'approved' check(status in ('approved','disabled')),
  granted_at timestamptz not null default now(),
  primary key(user_id,hospital_id)
);
create index if not exists doctor_hospital_memberships_hospital_idx
 on public.doctor_hospital_memberships(hospital_id,status);
alter table public.doctor_hospital_memberships enable row level security;
grant select on public.doctor_hospital_memberships to authenticated;
create policy doctor_hospital_memberships_self_read
 on public.doctor_hospital_memberships for select to authenticated
 using(user_id=(select auth.uid()));

-- All historically approved VISCERA staff are HUIM6 staff. No HUICK clinical
-- records or membership for ordinary staff are created here.
insert into public.doctor_hospital_memberships(user_id,hospital_id,member_role)
select user_id,'huim6',approved_role from public.doctor_profiles
where approval_status='approved' and approved_role in ('junior','senior')
on conflict(user_id,hospital_id) do nothing;
-- The already approved VISCERA owner is the sole HUICK preparation member.
insert into public.doctor_hospital_memberships(user_id,hospital_id,member_role)
select user_id,'huick',approved_role from public.doctor_profiles
where user_id='4fa3bd1b-6ee1-4b87-97eb-d18527025bc6'::uuid
  and is_admin=true and approval_status='approved'
  and approved_role in ('junior','senior')
on conflict(user_id,hospital_id) do nothing;

-- Do not create multi-tenant privileges from user-editable Auth metadata.
create or replace function public.viscera_has_hospital_access(p_hospital_id text)
returns boolean language sql stable security invoker set search_path=''
as $func$
  select (select auth.uid()) is not null and exists (
    select 1
      from public.doctor_hospital_memberships membership
      join public.doctor_profiles doctor on doctor.user_id=membership.user_id
     where membership.user_id=(select auth.uid())
       and membership.hospital_id=p_hospital_id
       and membership.status='approved'
       and doctor.approval_status='approved'
       and doctor.approved_role in ('junior','senior')
       and doctor.approved_role=membership.member_role
  );
$func$;
revoke execute on function public.viscera_has_hospital_access(text)
 from public, anon;
grant execute on function public.viscera_has_hospital_access(text) to authenticated;

-- Keep the HUIM6 authorization synchronized with the existing approval UI.
create schema if not exists viscera_private;
create or replace function viscera_private.sync_huim6_membership()
returns trigger language plpgsql security definer set search_path=''
as $func$
begin
 if new.approval_status='approved' and new.approved_role in ('junior','senior') then
   insert into public.doctor_hospital_memberships(user_id,hospital_id,member_role,status)
   values(new.user_id,'huim6',new.approved_role,'approved')
   on conflict(user_id,hospital_id)
   do update set member_role=excluded.member_role,status='approved';
 else
   update public.doctor_hospital_memberships
      set status='disabled'
    where user_id=new.user_id and hospital_id='huim6';
 end if;
 return new;
end
$func$;
create trigger viscera_sync_huim6_membership
 after insert or update of approval_status,approved_role on public.doctor_profiles
 for each row execute function viscera_private.sync_huim6_membership();

-- Each existing record is tagged HUIM6 via a non-destructive additive default.
do $migration$
declare t text;
begin
 foreach t in array array[
  'bloc_program_imports','bloc_program_entries','bloc_program_all_entries',
  'bloc_patient_records','manual_patient_records','manual_bloc_links',
  'viscera_notifications','viscera_notification_preferences','push_devices'
 ] loop
   execute format(
    'alter table public.%I add column hospital_id text not null default %L references public.viscera_hospitals(id)',
    t,'huim6'
   );
   execute format('create index %I on public.%I(hospital_id)',
     t||'_hospital_id_idx',t);
   execute format(
    'create policy %I on public.%I as restrictive for all to authenticated using (public.viscera_has_hospital_access(hospital_id)) with check (public.viscera_has_hospital_access(hospital_id))',
    t||'_hospital_boundary', t);
 end loop;
end
$migration$;

-- Enforce tenant integrity at the database level, not only through clients.
alter table public.bloc_program_imports
 add constraint bloc_program_imports_site_key unique(id,hospital_id);
alter table public.bloc_program_entries
 add constraint bloc_program_entries_site_key unique(id,hospital_id),
 add constraint bloc_program_entries_site_import_fk
 foreign key(import_id,hospital_id)
 references public.bloc_program_imports(id,hospital_id);
alter table public.bloc_program_all_entries
 add constraint bloc_program_all_entries_site_import_fk
 foreign key(import_id,hospital_id)
 references public.bloc_program_imports(id,hospital_id),
 add constraint bloc_program_all_entries_site_clinical_fk
 foreign key(clinical_entry_id,hospital_id)
 references public.bloc_program_entries(id,hospital_id);
alter table public.bloc_patient_records
 add constraint bloc_patient_records_site_entry_fk
 foreign key(entry_id,hospital_id)
 references public.bloc_program_entries(id,hospital_id);
alter table public.manual_patient_records
 add constraint manual_patient_records_site_key unique(id,hospital_id);
alter table public.manual_bloc_links
 add constraint manual_bloc_links_site_manual_fk
 foreign key(manual_id,hospital_id)
 references public.manual_patient_records(id,hospital_id),
 add constraint manual_bloc_links_site_entry_fk
 foreign key(entry_id,hospital_id)
 references public.bloc_program_entries(id,hospital_id);

-- Definer RPCs can bypass RLS; guard the actual writes in triggers too.
create or replace function viscera_private.guard_hospital_record()
returns trigger language plpgsql security invoker set search_path=''
as $func$
begin
 if tg_op='UPDATE' and new.hospital_id is distinct from old.hospital_id then
   raise exception 'The patient record hospital cannot be changed'
    using errcode='42501';
 end if;
 if (select auth.uid()) is not null and not public.viscera_has_hospital_access(new.hospital_id) then
   raise exception 'This doctor is not authorized for the record hospital'
    using errcode='42501';
 end if;
 return new;
end;
$func$;
do $triggers$
declare t text;
begin
 foreach t in array array[
  'bloc_program_imports','bloc_program_entries','bloc_program_all_entries',
  'bloc_patient_records','manual_patient_records','manual_bloc_links',
  'viscera_notifications','viscera_notification_preferences','push_devices'
 ] loop
   execute format(
    'create trigger %I before insert or update on public.%I for each row execute function viscera_private.guard_hospital_record()',
    t||'_guard_hospital',t
   );
 end loop;
end
$triggers$;
