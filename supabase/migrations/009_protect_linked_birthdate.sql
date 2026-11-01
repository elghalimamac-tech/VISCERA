CREATE OR REPLACE FUNCTION public.viscera_save_manual_patient_record(p_id uuid, p_expected_version bigint, p_clinical_data jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 if exists(select 1 from public.manual_bloc_links l
   where l.manual_id=p_id and l.confirmed_birth_date is distinct from v_birth)
 then raise exception 'Birth date of a verified linked patient cannot change without identity reconciliation'
   using errcode='23514'; end if;
 update public.manual_patient_records set
  clinical_data=p_clinical_data,birth_date=v_birth,surgery_type=v_surgery,
  version=version+1,updated_by=v_uid,updated_at=now()
 where id=p_id and version=p_expected_version returning version into v_new;
 if v_new is null then raise exception 'Record version conflict, reload required' using errcode='40001';end if;
 return v_new;
end;
$function$
