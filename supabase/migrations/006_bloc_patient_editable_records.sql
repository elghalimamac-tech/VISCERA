-- VISCERA — dossier clinique partage pour chaque ligne de programme operatoire.
-- Installation effective sur le projet VISCERA (RLS staff approuve uniquement).
create table if not exists public.bloc_patient_records (
  entry_id bigint primary key references public.bloc_program_entries(id) on delete restrict,
  clinical_data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(clinical_data)='object' and pg_column_size(clinical_data)<120000),
  version bigint not null default 1 check(version>=1),
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now()
);
alter table public.bloc_patient_records enable row level security;
revoke all on public.bloc_patient_records from anon,authenticated;
grant select,insert,update on public.bloc_patient_records to authenticated;
create policy bloc_patient_staff_read on public.bloc_patient_records
  for select to authenticated using (exists (
    select 1 from public.doctor_profiles p
    where p.user_id=(select auth.uid())
      and p.approval_status='approved' and p.approved_role is not null));
create policy bloc_patient_staff_insert on public.bloc_patient_records
  for insert to authenticated with check (
    updated_by=(select auth.uid()) and exists (
      select 1 from public.doctor_profiles p
      where p.user_id=(select auth.uid())
        and p.approval_status='approved' and p.approved_role is not null));
create policy bloc_patient_staff_update on public.bloc_patient_records
  for update to authenticated using (exists (
    select 1 from public.doctor_profiles p
    where p.user_id=(select auth.uid())
      and p.approval_status='approved' and p.approved_role is not null))
  with check (
    updated_by=(select auth.uid()) and exists (
      select 1 from public.doctor_profiles p
      where p.user_id=(select auth.uid())
        and p.approval_status='approved' and p.approved_role is not null));

-- Transaction atomique, droits du medecin invocateur, version anti-ecrasement.
create or replace function public.viscera_save_bloc_patient_record(
 p_entry_id bigint,p_expected_version bigint,p_clinical_data jsonb
) returns bigint
language plpgsql security invoker set search_path=''
as $$
declare v_new bigint;
begin
 if (select auth.uid()) is null or p_entry_id is null
   or p_expected_version is null or p_expected_version<0
   or jsonb_typeof(p_clinical_data) is distinct from 'object'
   or pg_catalog.pg_column_size(p_clinical_data)>120000
 then raise exception 'Invalid patient record update' using errcode='22023';
 end if;
 if p_expected_version=0 then
   insert into public.bloc_patient_records
     (entry_id,clinical_data,updated_by)
   values (p_entry_id,p_clinical_data,(select auth.uid()))
   on conflict(entry_id) do nothing returning version into v_new;
 else
   update public.bloc_patient_records set
     clinical_data=p_clinical_data,
     version=version+1,updated_by=(select auth.uid()),updated_at=now()
   where entry_id=p_entry_id and version=p_expected_version
   returning version into v_new;
 end if;
 if v_new is null then
   raise exception 'Record modified elsewhere; refresh required' using errcode='40001';
 end if;
 return v_new;
end;
$$;
revoke all on function public.viscera_save_bloc_patient_record(bigint,bigint,jsonb)
  from public,anon,authenticated;
grant execute on function public.viscera_save_bloc_patient_record(bigint,bigint,jsonb)
  to authenticated;

create schema if not exists viscera_private;
create table if not exists viscera_private.bloc_clinical_edit_audit (
  audit_id bigint generated always as identity primary key,
  entry_id bigint not null,version bigint not null,
  edited_by uuid not null,
  edited_at timestamptz not null default now()
);
revoke all on schema viscera_private from public,anon,authenticated;
revoke all on viscera_private.bloc_clinical_edit_audit from public,anon,authenticated;
create or replace function viscera_private.audit_bloc_clinical_edit()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 insert into viscera_private.bloc_clinical_edit_audit (entry_id,version,edited_by)
 values(new.entry_id,new.version,new.updated_by);
 return new;
end;
$$;
revoke all on function viscera_private.audit_bloc_clinical_edit()
  from public,anon,authenticated;
drop trigger if exists audit_bloc_clinical_record on public.bloc_patient_records;
create trigger audit_bloc_clinical_record
 after insert or update on public.bloc_patient_records
 for each row execute function viscera_private.audit_bloc_clinical_edit();
