-- VISCERA — admissions manuelles partagees et tracees. RLS personnel medical approuve.
create table if not exists public.manual_patient_records (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 2 and 200),
  name_key text generated always as (lower(regexp_replace(btrim(name),'[[:space:]]+',' ','g'))) stored,
  origin text not null check (origin in ('Urgences','Consultation')),
  procedure_name text not null check (length(btrim(procedure_name)) between 2 and 400),
  block_at timestamptz not null,
  block_date date not null,
  block_timing text not null check (block_timing in ('Immédiat','Différé')),
  clinical_data jsonb not null check (
    jsonb_typeof(clinical_data)='object' and pg_column_size(clinical_data)<120000),
  version bigint not null default 1 check (version>=1),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null references auth.users(id),
  constraint manual_patient_same_date unique(name_key,block_date),
  constraint manual_patient_block_date_matches check (
    (block_at at time zone 'Africa/Casablanca')::date=block_date)
);
create index if not exists manual_patients_date_idx
  on public.manual_patient_records (block_date desc, created_at desc);
alter table public.manual_patient_records enable row level security;
revoke all on public.manual_patient_records from public,anon,authenticated;
grant select on public.manual_patient_records to authenticated;
create policy manual_patient_staff_read on public.manual_patient_records for select
to authenticated using (
  exists(select 1 from public.doctor_profiles p where
    p.user_id=(select auth.uid())
    and p.approval_status='approved'
    and p.approved_role in ('junior','senior'))
);

-- L'ecriture directe par un client est interdite : seule la RPC valide
-- les admissions et garantit les controles de doublon et de version.
create or replace function public.viscera_create_manual_patient(
  p_name text,p_origin text,p_procedure text,p_block_at timestamptz,
  p_block_date date,p_block_timing text,p_clinical_data jsonb
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_uid uuid := (select auth.uid()); v_id uuid; v_key text;
begin
  if v_uid is null or not exists(
    select 1 from public.doctor_profiles d where d.user_id=v_uid
    and d.approval_status='approved' and d.approved_role in ('junior','senior')
  ) then raise exception 'Staff authorization required' using errcode='42501'; end if;
  if coalesce(length(btrim(p_name)),0) not between 2 and 200
    or p_origin not in ('Urgences','Consultation')
    or coalesce(length(btrim(p_procedure)),0) not between 2 and 400
    or p_block_timing not in ('Immédiat','Différé')
    or p_block_at is null or p_block_date is null
    or (p_block_at at time zone 'Africa/Casablanca')::date <> p_block_date
    or jsonb_typeof(p_clinical_data) is distinct from 'object'
    or pg_catalog.pg_column_size(p_clinical_data)>=120000
  then raise exception 'Invalid manual admission' using errcode='22023'; end if;
  v_key:=lower(regexp_replace(btrim(p_name),'[[:space:]]+',' ','g'));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_key||':'||p_block_date::text));
  if exists(
    select 1 from public.manual_patient_records m
    where m.name_key=v_key and m.block_date=p_block_date
  ) or exists(
    select 1 from public.bloc_program_entries e
    join public.bloc_program_imports i on i.id=e.import_id and i.is_current=true
    where i.program_date=p_block_date
      and lower(regexp_replace(btrim(e.patient_name),'[[:space:]]+',' ','g'))=v_key
  ) then raise exception 'MANUAL_ADMISSION_DUPLICATE' using errcode='23505'; end if;
  insert into public.manual_patient_records
    (name,origin,procedure_name,block_at,block_date,block_timing,
      clinical_data,created_by,updated_by)
  values (btrim(p_name),p_origin,btrim(p_procedure),p_block_at,p_block_date,
      p_block_timing,p_clinical_data,v_uid,v_uid)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.viscera_create_manual_patient(
 text,text,text,timestamptz,date,text,jsonb) from public,anon,authenticated;
grant execute on function public.viscera_create_manual_patient(
 text,text,text,timestamptz,date,text,jsonb) to authenticated;

create or replace function public.viscera_save_manual_patient_record(
  p_id uuid,p_expected_version bigint,p_clinical_data jsonb
) returns bigint language plpgsql security definer set search_path=''
as $$
declare v_uid uuid := (select auth.uid()); v_new bigint;
begin
  if v_uid is null or not exists(
    select 1 from public.doctor_profiles d where d.user_id=v_uid
    and d.approval_status='approved' and d.approved_role in ('junior','senior')
  ) then raise exception 'Staff authorization required' using errcode='42501'; end if;
  if p_id is null or p_expected_version is null or p_expected_version<1
    or jsonb_typeof(p_clinical_data) is distinct from 'object'
    or pg_catalog.pg_column_size(p_clinical_data)>=120000
  then raise exception 'Invalid manual admission update' using errcode='22023'; end if;
  update public.manual_patient_records set
    clinical_data=p_clinical_data, version=version+1,
    updated_by=v_uid,updated_at=now()
    where id=p_id and version=p_expected_version returning version into v_new;
  if v_new is null then
    raise exception 'Record version conflict, reload required' using errcode='40001';
  end if;
  return v_new;
end;
$$;
revoke all on function public.viscera_save_manual_patient_record(uuid,bigint,jsonb)
  from public,anon,authenticated;
grant execute on function public.viscera_save_manual_patient_record(uuid,bigint,jsonb)
  to authenticated;

create table if not exists viscera_private.manual_clinical_edit_audit (
  audit_id bigint generated always as identity primary key,
  patient_id uuid not null,
  version bigint not null,
  edited_by uuid not null,
  edited_at timestamptz not null default now()
);
revoke all on viscera_private.manual_clinical_edit_audit from public,anon,authenticated;
create or replace function viscera_private.audit_manual_clinical_edit()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  insert into viscera_private.manual_clinical_edit_audit(patient_id,version,edited_by)
  values(new.id,new.version,new.updated_by);
  return new;
end;
$$;
revoke all on function viscera_private.audit_manual_clinical_edit()
  from public,anon,authenticated;
create trigger audit_manual_clinical_record after insert or update
  on public.manual_patient_records for each row
  execute function viscera_private.audit_manual_clinical_edit();
