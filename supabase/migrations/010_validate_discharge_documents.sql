-- Bloque côté serveur toute sortie sans dossier complet et décision médicale.
-- Déclenché pour les admissions manuelles ET les dossiers du programme du bloc.
create or replace function viscera_private.validate_clinical_discharge()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
  required_doc text;
  optional_doc text;
  doc jsonb;
  docs jsonb;
  source_stage text;
begin
  if new.clinical_data->>'stage' <> 'discharged' then
    return new;
  end if;
  if tg_op='INSERT' then
    raise exception 'Discharge requires a previously admitted postoperative record'
      using errcode='23514';
  end if;
  source_stage := old.clinical_data->>'stage';
  if source_stage is distinct from 'postoperative'
     and source_stage is distinct from 'dischargeReady'
     and source_stage is distinct from 'discharged'
  then
    raise exception 'Only postoperative admitted patients may be discharged'
      using errcode='23514';
  end if;
  if nullif(new.clinical_data->>'admittedAt','') is null
     or nullif(new.clinical_data->>'dischargeAt','') is null
     or new.clinical_data->>'dischargeMedicalValidation' is distinct from 'true'
  then
    raise exception 'Admission and physician discharge validation required'
      using errcode='23514';
  end if;
  if new.clinical_data->>'insurance'='FAR'
     and new.clinical_data->>'dischargeFarValidation' is distinct from 'true'
  then
    raise exception 'FAR prescription confirmation is missing'
      using errcode='23514';
  end if;
  docs:=new.clinical_data->'documents';
  if jsonb_typeof(docs) is distinct from 'object' then
    raise exception 'Discharge documents are missing'
      using errcode='23514';
  end if;
  foreach required_doc in array array[
     'ordonnance_medicale','ordonnance_sortie','rapport',
     'cro','prestations','honoraires','rdv'
  ] loop
    doc:=docs->required_doc;
    if coalesce(doc->>'verified','false')<>'true'
       or coalesce(doc->>'notApplicable','false')='true'
       or (required_doc<>'rdv' and coalesce(doc->>'stamped','false')<>'true')
    then
      raise exception 'Mandatory discharge document % not verified',required_doc
        using errcode='23514';
    end if;
  end loop;
  foreach optional_doc in array array[
    'anapath','bilans','imagerie','certificat'
  ] loop
    doc:=docs->optional_doc;
    if coalesce(doc->>'notApplicable','false')<>'true'
       and (coalesce(doc->>'verified','false')<>'true'
         or coalesce(doc->>'stamped','false')<>'true')
    then
      raise exception 'Discharge document % must be verified or N/A',optional_doc
        using errcode='23514';
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function viscera_private.validate_clinical_discharge()
from public,anon,authenticated;

drop trigger if exists validate_manual_discharge on public.manual_patient_records;
create trigger validate_manual_discharge
before insert or update of clinical_data on public.manual_patient_records
for each row execute function viscera_private.validate_clinical_discharge();

drop trigger if exists validate_bloc_discharge on public.bloc_patient_records;
create trigger validate_bloc_discharge
before insert or update of clinical_data on public.bloc_patient_records
for each row execute function viscera_private.validate_clinical_discharge();