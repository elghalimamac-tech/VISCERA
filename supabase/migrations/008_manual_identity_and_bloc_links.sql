-- Identité clinique, chirurgie et rapprochement contrôlé des programmes HUIM6.
alter table public.manual_patient_records
  add column if not exists birth_date date,
  add column if not exists surgery_type text not null default 'À préciser';
alter table public.manual_patient_records
  drop constraint if exists manual_patient_same_date;
create unique index if not exists manual_patient_verified_identity_day_uq
 on public.manual_patient_records (name_key,birth_date,block_date)
 where birth_date is not null;

-- Le rattachement est une action explicite du médecin qui vérifie l'identité.
create table if not exists public.manual_bloc_links (
  entry_id bigint primary key references public.bloc_program_entries(id) on delete restrict,
  manual_id uuid not null references public.manual_patient_records(id) on delete restrict,
  confirmed_birth_date date not null,
  linked_by uuid not null references auth.users(id),
  linked_at timestamptz not null default now()
);
create index if not exists manual_bloc_links_manual_idx
  on public.manual_bloc_links(manual_id);
alter table public.manual_bloc_links enable row level security;
revoke all on public.manual_bloc_links from public,anon,authenticated;
grant select on public.manual_bloc_links to authenticated;
create policy manual_bloc_staff_read on public.manual_bloc_links
  for select to authenticated using (
    exists(select 1 from public.doctor_profiles p
      where p.user_id=(select auth.uid())
        and p.approval_status='approved' and p.approved_role in ('junior','senior'))
  );

-- Retirer la première signature, qui bloquait les homonymes et ne contrôlait pas la naissance.
drop function if exists public.viscera_create_manual_patient(
 text,text,text,timestamptz,date,text,jsonb);
create or replace function public.viscera_create_manual_patient(
 p_name text,p_origin text,p_procedure text,p_block_at timestamptz,
 p_block_date date,p_block_timing text,p_birth_date date,p_surgery_type text,
 p_clinical_data jsonb
) returns uuid language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_id uuid;v_key text;
begin
 if v_uid is null or not exists(
   select 1 from public.doctor_profiles d where d.user_id=v_uid
     and d.approval_status='approved' and d.approved_role in ('junior','senior')
 ) then raise exception 'Staff authorization required' using errcode='42501';end if;
 if coalesce(length(btrim(p_name)),0) not between 2 and 200
    or p_origin not in ('Urgences','Consultation')
    or coalesce(length(btrim(p_procedure)),0) not between 2 and 400
    or p_block_timing not in ('Immédiat','Différé')
    or p_block_at is null or p_block_date is null
    or (p_block_at at time zone 'Africa/Casablanca')::date<>p_block_date
    or p_birth_date is null or p_birth_date>current_date
    or p_birth_date<date '1900-01-01'
    or coalesce(length(btrim(p_surgery_type)),0) not between 2 and 120
    or jsonb_typeof(p_clinical_data) is distinct from 'object'
    or pg_catalog.pg_column_size(p_clinical_data)>=120000
    or p_clinical_data->>'birthDate'<>p_birth_date::text
 then raise exception 'Invalid manual admission' using errcode='22023';end if;
 v_key:=lower(regexp_replace(btrim(p_name),'[[:space:]]+',' ','g'));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_key||p_birth_date::text||p_block_date::text));
 if exists(select 1 from public.manual_patient_records m
    where m.name_key=v_key and m.birth_date=p_birth_date and m.block_date=p_block_date)
 then raise exception 'MANUAL_ADMISSION_DUPLICATE' using errcode='23505';end if;
 -- Pas de fusion automatique avec les programmes car ils n'indiquent pas la date de naissance.
 insert into public.manual_patient_records
   (name,origin,procedure_name,block_at,block_date,block_timing,
    birth_date,surgery_type,clinical_data,created_by,updated_by)
 values (btrim(p_name),p_origin,btrim(p_procedure),p_block_at,p_block_date,
    p_block_timing,p_birth_date,btrim(p_surgery_type),p_clinical_data,v_uid,v_uid)
 returning id into v_id;
 return v_id;
end;
$$;
revoke all on function public.viscera_create_manual_patient(
 text,text,text,timestamptz,date,text,date,text,jsonb) from public,anon,authenticated;
grant execute on function public.viscera_create_manual_patient(
 text,text,text,timestamptz,date,text,date,text,jsonb) to authenticated;

create or replace function public.viscera_save_manual_patient_record(
 p_id uuid,p_expected_version bigint,p_clinical_data jsonb
) returns bigint language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_new bigint;v_birth date;v_surgery text;
begin
 if v_uid is null or not exists(
    select 1 from public.doctor_profiles d where d.user_id=v_uid
      and d.approval_status='approved' and d.approved_role in ('junior','senior')
 ) then raise exception 'Staff authorization required' using errcode='42501';end if;
 if p_id is null or p_expected_version is null or p_expected_version<1
    or jsonb_typeof(p_clinical_data) is distinct from 'object'
    or pg_catalog.pg_column_size(p_clinical_data)>=120000
 then raise exception 'Invalid update' using errcode='22023';end if;
 v_birth:=nullif(p_clinical_data->>'birthDate','')::date;
 v_surgery:=btrim(coalesce(p_clinical_data->>'surgeryType',''));
 if v_birth is null or v_birth>current_date or v_birth<date '1900-01-01'
    or length(v_surgery) not between 2 and 120
 then raise exception 'Missing identity or surgery type' using errcode='22023';end if;
 update public.manual_patient_records set
  clinical_data=p_clinical_data,birth_date=v_birth,surgery_type=v_surgery,
  version=version+1,updated_by=v_uid,updated_at=now()
 where id=p_id and version=p_expected_version returning version into v_new;
 if v_new is null then raise exception 'Record version conflict, reload required' using errcode='40001';end if;
 return v_new;
end;
$$;
revoke all on function public.viscera_save_manual_patient_record(uuid,bigint,jsonb)
 from public,anon,authenticated;
grant execute on function public.viscera_save_manual_patient_record(uuid,bigint,jsonb)
 to authenticated;

create or replace function public.viscera_link_manual_bloc_program(
 p_manual_id uuid,p_entry_id bigint,p_confirmed_birth_date date
) returns boolean language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_manual public.manual_patient_records%rowtype;
 v_program_name text;v_program_date date;v_existing bigint;
begin
 if v_uid is null or not exists(
    select 1 from public.doctor_profiles d where d.user_id=v_uid
      and d.approval_status='approved' and d.approved_role in ('junior','senior')
 ) then raise exception 'Staff authorization required' using errcode='42501';end if;
 select * into v_manual from public.manual_patient_records where id=p_manual_id for update;
 if not found or v_manual.origin<>'Consultation'
    or v_manual.birth_date is distinct from p_confirmed_birth_date
 then raise exception 'Verified consultation identity required' using errcode='22023';end if;
 select e.patient_name,i.program_date into v_program_name,v_program_date
 from public.bloc_program_entries e
 join public.bloc_program_imports i on i.id=e.import_id
 where e.id=p_entry_id and i.is_current=true;
 if not found or v_manual.block_date<>v_program_date
    or v_manual.name_key<>lower(regexp_replace(btrim(v_program_name),'[[:space:]]+',' ','g'))
 then raise exception 'Program identity/date mismatch' using errcode='22023';end if;
 -- Une fiche opératoire déjà annotée doit être rapprochée manuellement par
 -- procédure spécialisée pour ne jamais écraser des observations existantes.
 if exists(select 1 from public.bloc_patient_records r where r.entry_id=p_entry_id)
 then raise exception 'Program case has separate clinical annotations; reconciliation required'
   using errcode='23514';end if;
 insert into public.manual_bloc_links(entry_id,manual_id,confirmed_birth_date,linked_by)
 values(p_entry_id,p_manual_id,p_confirmed_birth_date,v_uid)
 on conflict(entry_id) do nothing returning entry_id into v_existing;
 if v_existing is null then raise exception 'Program already associated' using errcode='23505';end if;
 return true;
end;
$$;
revoke all on function public.viscera_link_manual_bloc_program(uuid,bigint,date)
 from public,anon,authenticated;
grant execute on function public.viscera_link_manual_bloc_program(uuid,bigint,date)
 to authenticated;