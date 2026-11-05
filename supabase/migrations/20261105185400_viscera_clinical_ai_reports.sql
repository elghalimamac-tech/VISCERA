-- Append-only history of GROQ-generated clinical reports per patient.
-- Direct writes are disallowed to authenticated clients: reports are saved
-- only by viscera-clinical-assist after doctor/hospital verification.
create table if not exists public.viscera_clinical_ai_reports (
  id uuid primary key default gen_random_uuid(),
  hospital_id text not null references public.viscera_hospitals(id),
  bloc_entry_id bigint,
  manual_patient_id uuid,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_by_name text not null default 'Médecin',
  model text not null,
  result jsonb not null,
  reference_catalog jsonb not null default '[]'::jsonb,
  bibliography_reviewed_at date,
  sources_live_verified boolean not null default false,
  constraint viscera_ai_one_patient check (
    (bloc_entry_id is not null and manual_patient_id is null) or
    (bloc_entry_id is null and manual_patient_id is not null)
  ),
  constraint viscera_ai_valid_result check (
    jsonb_typeof(result) = 'object' and pg_column_size(result) < 75000
  ),
  constraint viscera_ai_valid_references check (
    jsonb_typeof(reference_catalog) = 'array' and
    pg_column_size(reference_catalog) < 50000
  ),
  constraint viscera_ai_author_length check (
    char_length(created_by_name) between 1 and 160
  ),
  constraint viscera_ai_valid_model check (
    char_length(model) between 2 and 160
  ),
  constraint viscera_ai_bloc_hospital foreign key (bloc_entry_id, hospital_id)
    references public.bloc_program_entries(id, hospital_id) on delete restrict,
  constraint viscera_ai_manual_hospital foreign key (manual_patient_id, hospital_id)
    references public.manual_patient_records(id, hospital_id) on delete cascade
);

create index if not exists viscera_ai_bloc_timeline
  on public.viscera_clinical_ai_reports (bloc_entry_id, created_at desc)
  where bloc_entry_id is not null;

create index if not exists viscera_ai_manual_timeline
  on public.viscera_clinical_ai_reports (manual_patient_id, created_at desc)
  where manual_patient_id is not null;

alter table public.viscera_clinical_ai_reports enable row level security;
revoke all on table public.viscera_clinical_ai_reports from anon, authenticated;
grant select on table public.viscera_clinical_ai_reports to authenticated;

drop policy if exists viscera_ai_hospital_approved_read
  on public.viscera_clinical_ai_reports;
create policy viscera_ai_hospital_approved_read
  on public.viscera_clinical_ai_reports for select to authenticated
  using (public.viscera_has_hospital_access(hospital_id));
