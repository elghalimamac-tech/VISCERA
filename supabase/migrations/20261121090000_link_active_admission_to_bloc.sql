-- Rattacher une ligne opératoire à un séjour hospitalier déjà ouvert.
-- Contrôle explicite, mêmes site/nom/naissance, aucun effacement de données.
-- Un patient hospitalisé plusieurs jours avant le bloc conserve son dossier
-- MANUAL-*; l'entrée BLOC-* devient une référence opératoire liée.
create or replace function public.viscera_link_manual_bloc_program(
 p_manual_id uuid, p_entry_id bigint, p_confirmed_birth_date date
) returns boolean
language plpgsql security definer set search_path=''
as $function$
declare
 v_uid uuid := (select auth.uid());
 v_manual public.manual_patient_records%rowtype;
 v_program_name text;
 v_program_date date;
 v_admission_date date;
 v_stage text;
 v_existing bigint;
begin
 if v_uid is null or not exists(
   select 1 from public.doctor_profiles d where d.user_id=v_uid
     and d.approval_status='approved'
     and d.approved_role in ('junior','senior')
 ) then
   raise exception 'Staff authorization required' using errcode='42501';
 end if;

 select * into v_manual from public.manual_patient_records
   where id=p_manual_id and hospital_id='huim6' for update;
 if not found or v_manual.birth_date is null
   or v_manual.birth_date is distinct from p_confirmed_birth_date then
   raise exception 'Verified hospitalized identity required'
     using errcode='22023';
 end if;

 select e.patient_name,i.program_date into v_program_name,v_program_date
   from public.bloc_program_entries e
   join public.bloc_program_imports i on i.id=e.import_id
   where e.id=p_entry_id and e.hospital_id=v_manual.hospital_id
     and i.hospital_id=v_manual.hospital_id and i.is_current=true;
 if not found or v_manual.name_key<>
     lower(regexp_replace(btrim(v_program_name),'[[:space:]]+',' ','g')) then
   raise exception 'Program identity or site mismatch' using errcode='22023';
 end if;

 v_stage := coalesce(v_manual.clinical_data->>'stage','');
 v_admission_date := nullif(
   left(coalesce(v_manual.clinical_data->>'admittedAt',''),10),'')::date;

 -- Hospitalisé : le jour du bloc ne peut précéder le début du séjour.
 -- Ancienne consultation programmée non admise : comportement historique
 -- limité au même jour de bloc.
 if not (
   (v_stage in ('preoperative','inTheatre','postoperative','dischargeReady')
     and v_admission_date is not null
     and v_program_date>=v_admission_date)
   or
   (v_manual.origin='Consultation' and v_stage='scheduled'
     and v_admission_date is null
     and v_manual.block_date=v_program_date)
 ) then
   raise exception 'No compatible active hospitalization on programme date'
     using errcode='22023';
 end if;

 -- Ne jamais jeter les saisies d'une seconde fiche opératoire annotée.
 -- Ce cas nécessite une réconciliation clinique spécifique.
 if exists(
   select 1 from public.bloc_patient_records r
   where r.entry_id=p_entry_id and r.hospital_id=v_manual.hospital_id
 ) then
   raise exception 'Program has separate clinical notes: manual reconciliation required'
     using errcode='23514';
 end if;

 insert into public.manual_bloc_links(
   entry_id,manual_id,confirmed_birth_date,linked_by,hospital_id)
 values(p_entry_id,p_manual_id,p_confirmed_birth_date,v_uid,v_manual.hospital_id)
 on conflict(entry_id) do nothing returning entry_id into v_existing;
 if v_existing is null then
   raise exception 'Program already associated' using errcode='23505';
 end if;
 return true;
end;
$function$;

revoke all on function public.viscera_link_manual_bloc_program(uuid,bigint,date)
 from public,anon,authenticated;
grant execute on function public.viscera_link_manual_bloc_program(uuid,bigint,date)
 to authenticated;
