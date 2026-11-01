-- VISCERA — Gmail -> programme opératoire (schéma également installé dans Supabase).
create table if not exists public.bloc_program_imports (
 id uuid primary key default gen_random_uuid(),
 program_date date not null,
 source_message_id text not null,
 attachment_name text not null,
 source_received_at timestamptz not null,
 checksum text not null,
 is_current boolean not null default true,
 imported_at timestamptz not null default now(),
 unique (source_message_id, attachment_name)
);
create table if not exists public.bloc_program_entries (
 id bigint generated always as identity primary key,
 import_id uuid not null references public.bloc_program_imports(id) on delete cascade,
 sequence_no integer not null,
 room text not null,
 scheduled_time text,
 hospital_arrival text,
 theatre_arrival text,
 source_service text,
 patient_name text not null,
 procedure_name text not null,
 surgeon text not null,
 assistant text,
 nurse text,
 anaesthetist text,
 iar text,
 source_status text,
 unique (import_id, sequence_no)
);
alter table public.bloc_program_imports enable row level security;
alter table public.bloc_program_entries enable row level security;
revoke all on public.bloc_program_imports,public.bloc_program_entries from anon,authenticated;
grant select on public.bloc_program_imports,public.bloc_program_entries to authenticated;
drop policy if exists bloc_program_staff_select on public.bloc_program_imports;
create policy bloc_program_staff_select on public.bloc_program_imports
for select to authenticated using (
 exists (select 1 from public.doctor_profiles p
 where p.user_id=auth.uid() and p.approval_status='approved' and p.approved_role is not null)
);
drop policy if exists bloc_entry_staff_select on public.bloc_program_entries;
create policy bloc_entry_staff_select on public.bloc_program_entries
for select to authenticated using (
 exists (select 1 from public.doctor_profiles p
 where p.user_id=auth.uid() and p.approval_status='approved' and p.approved_role is not null)
);

create or replace function public.viscera_ingest_bloc_program(
 p_date date,p_message_id text,p_filename text,p_received_at timestamptz,
 p_checksum text,p_rows jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
 v_duplicate uuid;
 v_latest timestamptz;
 v_import uuid;
 v_item jsonb;
 v_position integer:=0;
begin
 if p_date is null or p_received_at is null
   or coalesce(length(p_message_id),0) not between 5 and 180
   or coalesce(length(p_filename),0) not between 10 and 200
   or p_checksum !~ '^[a-f0-9]{64}$'
   or jsonb_typeof(p_rows) is distinct from 'array'
   or jsonb_array_length(p_rows)>200
 then raise exception 'Invalid operating program' using errcode='22023';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_date::text));
 select id into v_duplicate from public.bloc_program_imports
 where source_message_id=p_message_id and attachment_name=p_filename;
 if v_duplicate is not null then return jsonb_build_object('status','duplicate'); end if;
 select source_received_at into v_latest from public.bloc_program_imports
 where program_date=p_date and is_current=true;
 if v_latest is not null and v_latest > p_received_at
 then return jsonb_build_object('status','stale'); end if;
 for v_item in select value from jsonb_array_elements(p_rows)
 loop
   if jsonb_typeof(v_item) is distinct from 'object'
     or coalesce(length(v_item->>'patient_name'),0) not between 2 and 200
     or coalesce(length(v_item->>'surgeon'),0) not between 2 and 160
     or coalesce(length(v_item->>'procedure_name'),0) not between 2 and 400
   then raise exception 'Invalid program entry' using errcode='22023';
   end if;
 end loop;
 update public.bloc_program_imports set is_current=false
 where program_date=p_date and is_current=true;
 insert into public.bloc_program_imports
  (program_date,source_message_id,attachment_name,source_received_at,checksum,is_current)
 values (p_date,p_message_id,p_filename,p_received_at,p_checksum,true)
 returning id into v_import;
 for v_item in select value from jsonb_array_elements(p_rows)
 loop
  v_position:=v_position+1;
  insert into public.bloc_program_entries(
   import_id,sequence_no,room,scheduled_time,hospital_arrival,theatre_arrival,
   source_service,patient_name,procedure_name,surgeon,assistant,nurse,anaesthetist,iar,source_status)
  values (
   v_import,v_position,coalesce(v_item->>'room',''),v_item->>'scheduled_time',
   v_item->>'hospital_arrival',v_item->>'theatre_arrival',
   v_item->>'source_service',v_item->>'patient_name',v_item->>'procedure_name',
   v_item->>'surgeon',v_item->>'assistant',v_item->>'nurse',
   v_item->>'anaesthetist',v_item->>'iar',v_item->>'source_status');
 end loop;
 return jsonb_build_object('status','imported','count',v_position);
end;
$$;
revoke execute on function public.viscera_ingest_bloc_program(date,text,text,timestamptz,text,jsonb)
 from public,anon,authenticated;
grant execute on function public.viscera_ingest_bloc_program(date,text,text,timestamptz,text,jsonb)
 to service_role;
