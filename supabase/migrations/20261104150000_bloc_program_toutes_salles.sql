-- Programme opératoire général : indépendant des dossiers cliniques VISCERA.
-- Ne jamais ajouter les autres spécialités dans bloc_program_entries,
-- car les anciennes versions créeraient des dossiers patients.
CREATE TABLE IF NOT EXISTS public.bloc_program_all_entries (
  id bigint generated always as identity PRIMARY KEY,
  import_id uuid NOT NULL REFERENCES public.bloc_program_imports(id) ON DELETE CASCADE,
  sequence_no integer NOT NULL,
  room text NOT NULL,
  scheduled_time text,
  hospital_arrival text,
  theatre_arrival text,
  source_service text,
  patient_name text NOT NULL,
  procedure_name text NOT NULL,
  surgeon text NOT NULL,
  assistant text,
  nurse text,
  anaesthetist text,
  iar text,
  source_status text,
  is_visceral boolean NOT NULL DEFAULT false,
  clinical_entry_id bigint REFERENCES public.bloc_program_entries(id),
  UNIQUE(import_id,sequence_no)
);
CREATE INDEX IF NOT EXISTS bloc_all_entries_import_room_idx
  ON public.bloc_program_all_entries(import_id,room,sequence_no);
ALTER TABLE public.bloc_program_all_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bloc_program_all_entries FROM anon,authenticated;
GRANT SELECT ON public.bloc_program_all_entries TO authenticated;
DROP POLICY IF EXISTS bloc_all_entries_staff_select ON public.bloc_program_all_entries;
CREATE POLICY bloc_all_entries_staff_select ON public.bloc_program_all_entries
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.doctor_profiles p
      WHERE p.user_id=auth.uid()
        AND p.approval_status='approved'
        AND p.approved_role IS NOT NULL)
  );

-- Import atomique : toutes les salles dans le tableau et seulement
-- la chirurgie viscérale dans les entrées liées aux dossiers patients.
CREATE OR REPLACE FUNCTION public.viscera_ingest_bloc_program(
  p_date date,p_message_id text,p_filename text,p_received_at timestamptz,
  p_checksum text,p_rows jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
  v_duplicate uuid;
  v_latest timestamptz;
  v_import uuid;
  v_item jsonb;
  v_position integer := 0;
  v_clinical_position integer := 0;
  v_clinical_id bigint;
  v_visceral boolean;
BEGIN
  IF p_date IS NULL OR p_received_at IS NULL
     OR coalesce(length(p_message_id),0) NOT BETWEEN 5 AND 180
     OR coalesce(length(p_filename),0) NOT BETWEEN 10 AND 200
     OR p_checksum !~ '^[a-f0-9]{64}$'
     OR jsonb_typeof(p_rows) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_rows)>200
  THEN RAISE EXCEPTION 'Invalid operating program' USING errcode='22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_date::text));
  SELECT id INTO v_duplicate FROM public.bloc_program_imports
    WHERE source_message_id=p_message_id AND attachment_name=p_filename;
  IF v_duplicate IS NOT NULL THEN
    RETURN jsonb_build_object('status','duplicate');
  END IF;

  SELECT source_received_at INTO v_latest FROM public.bloc_program_imports
    WHERE program_date=p_date AND is_current=true;
  IF v_latest IS NOT NULL AND v_latest > p_received_at THEN
    RETURN jsonb_build_object('status','stale');
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_rows)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object'
      OR coalesce(length(v_item->>'patient_name'),0) NOT BETWEEN 2 AND 200
      OR coalesce(length(v_item->>'surgeon'),0) NOT BETWEEN 2 AND 160
      OR coalesce(length(v_item->>'procedure_name'),0) NOT BETWEEN 2 AND 400
      OR (v_item ? 'is_visceral' AND
          jsonb_typeof(v_item->'is_visceral') IS DISTINCT FROM 'boolean')
    THEN RAISE EXCEPTION 'Invalid program entry' USING errcode='22023';
    END IF;
  END LOOP;

  UPDATE public.bloc_program_imports SET is_current=false
    WHERE program_date=p_date AND is_current=true;
  INSERT INTO public.bloc_program_imports
    (program_date,source_message_id,attachment_name,source_received_at,checksum,is_current)
  VALUES (p_date,p_message_id,p_filename,p_received_at,p_checksum,true)
  RETURNING id INTO v_import;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_rows)
  LOOP
    v_position := v_position + 1;
    -- Si l'ancienne fonction envoie uniquement des actes viscéraux,
    -- la valeur absente conserve la compatibilité.
    v_visceral := coalesce((v_item->>'is_visceral')::boolean, true);
    v_clinical_id := NULL;
    IF v_visceral THEN
      v_clinical_position := v_clinical_position + 1;
      INSERT INTO public.bloc_program_entries(
        import_id,sequence_no,room,scheduled_time,hospital_arrival,theatre_arrival,
        source_service,patient_name,procedure_name,surgeon,assistant,nurse,
        anaesthetist,iar,source_status
      ) VALUES (
        v_import,v_clinical_position,coalesce(v_item->>'room',''),
        v_item->>'scheduled_time',v_item->>'hospital_arrival',
        v_item->>'theatre_arrival',v_item->>'source_service',
        v_item->>'patient_name',v_item->>'procedure_name',v_item->>'surgeon',
        v_item->>'assistant',v_item->>'nurse',v_item->>'anaesthetist',
        v_item->>'iar',v_item->>'source_status'
      ) RETURNING id INTO v_clinical_id;
    END IF;

    INSERT INTO public.bloc_program_all_entries(
      import_id,sequence_no,room,scheduled_time,hospital_arrival,theatre_arrival,
      source_service,patient_name,procedure_name,surgeon,assistant,nurse,
      anaesthetist,iar,source_status,is_visceral,clinical_entry_id
    ) VALUES (
      v_import,v_position,coalesce(v_item->>'room',''),
      v_item->>'scheduled_time',v_item->>'hospital_arrival',
      v_item->>'theatre_arrival',v_item->>'source_service',
      v_item->>'patient_name',v_item->>'procedure_name',v_item->>'surgeon',
      v_item->>'assistant',v_item->>'nurse',v_item->>'anaesthetist',
      v_item->>'iar',v_item->>'source_status',v_visceral,v_clinical_id
    );
  END LOOP;

  RETURN jsonb_build_object('status','imported','count',v_position,
    'visceral_count',v_clinical_position);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.viscera_ingest_bloc_program(date,text,text,timestamptz,text,jsonb)
  FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.viscera_ingest_bloc_program(date,text,text,timestamptz,text,jsonb)
  TO service_role;
