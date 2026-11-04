-- Fix PostgREST 300: one FK per parent-child relationship.
-- Existing HUIM6 data are unchanged. Composite FKs enforce hospital boundaries.
alter table public.bloc_program_entries
 drop constraint bloc_program_entries_import_id_fkey,
 drop constraint bloc_program_entries_site_import_fk;
alter table public.bloc_program_entries
 add constraint bloc_program_entries_site_import_fk
 foreign key (import_id,hospital_id)
 references public.bloc_program_imports(id,hospital_id) on delete cascade;

alter table public.bloc_program_all_entries
 drop constraint bloc_program_all_entries_import_id_fkey,
 drop constraint bloc_program_all_entries_clinical_entry_id_fkey,
 drop constraint bloc_program_all_entries_site_import_fk,
 drop constraint bloc_program_all_entries_site_clinical_fk;
alter table public.bloc_program_all_entries
 add constraint bloc_program_all_entries_site_import_fk
 foreign key (import_id,hospital_id)
 references public.bloc_program_imports(id,hospital_id) on delete cascade,
 add constraint bloc_program_all_entries_site_clinical_fk
 foreign key (clinical_entry_id,hospital_id)
 references public.bloc_program_entries(id,hospital_id);

alter table public.bloc_patient_records
 drop constraint bloc_patient_records_entry_id_fkey,
 drop constraint bloc_patient_records_site_entry_fk;
alter table public.bloc_patient_records
 add constraint bloc_patient_records_site_entry_fk
 foreign key (entry_id,hospital_id)
 references public.bloc_program_entries(id,hospital_id) on delete restrict;

alter table public.manual_bloc_links
 drop constraint manual_bloc_links_entry_id_fkey,
 drop constraint manual_bloc_links_manual_id_fkey,
 drop constraint manual_bloc_links_site_entry_fk,
 drop constraint manual_bloc_links_site_manual_fk;
alter table public.manual_bloc_links
 add constraint manual_bloc_links_site_entry_fk
 foreign key (entry_id,hospital_id)
 references public.bloc_program_entries(id,hospital_id) on delete restrict,
 add constraint manual_bloc_links_site_manual_fk
 foreign key (manual_id,hospital_id)
 references public.manual_patient_records(id,hospital_id) on delete restrict;
notify pgrst,'reload schema';
