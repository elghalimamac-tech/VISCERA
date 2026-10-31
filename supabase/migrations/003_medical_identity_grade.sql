-- VISCERA — identité médicale et grade déclaré à l'inscription.
-- Les valeurs déclarées ne donnent aucun droit : seul approved_role approuvé est autorisant.
alter table public.doctor_profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists junior_category text,
  add column if not exists internship_passage smallint,
  add column if not exists senior_title text;

alter table public.doctor_profiles
  add constraint viscera_first_name_length check (first_name is null or char_length(first_name) between 2 and 70),
  add constraint viscera_last_name_length check (last_name is null or char_length(last_name) between 2 and 70),
  add constraint viscera_junior_category_valid check (junior_category is null or junior_category in (
    'interne_1','interne_2','resident_1','resident_2','resident_3',
    'resident_4','resident_5'
  )),
  add constraint viscera_senior_title_valid check (senior_title is null or senior_title in ('Dr','Pr')),
  add constraint viscera_category_for_role check (
    (requested_role = 'junior' and senior_title is null)
    or (requested_role = 'senior' and junior_category is null and internship_passage is null)
  ),
  add constraint viscera_internship_passage_valid check (
    internship_passage is null or
    (junior_category = 'interne_1' and internship_passage in (1,2)) or
    (junior_category = 'interne_2' and internship_passage in (3,4))
  );

create or replace function viscera_private.register_doctor_profile()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  p_first text;
  p_last text;
  p_role text;
  p_category text;
  p_passage smallint;
  p_title text;
  p_display text;
begin
  p_first := nullif(btrim(coalesce(meta->>'first_name','')), '');
  p_last := nullif(btrim(coalesce(meta->>'last_name','')), '');
  if p_first is not null and char_length(p_first) not between 2 and 70 then p_first := null; end if;
  if p_last is not null and char_length(p_last) not between 2 and 70 then p_last := null; end if;

  p_role := coalesce(meta->>'requested_role','junior');
  if p_role not in ('junior','senior') then p_role := 'junior'; end if;

  if p_role = 'junior' then
    p_category := meta->>'junior_category';
    if p_category not in ('interne_1','interne_2','resident_1','resident_2',
                          'resident_3','resident_4','resident_5') then
      p_category := null;
    end if;
    if (p_category = 'interne_1' and meta->>'internship_passage' in ('1','2'))
       or (p_category = 'interne_2' and meta->>'internship_passage' in ('3','4')) then
      p_passage := (meta->>'internship_passage')::smallint;
    end if;
    p_title := null;
  else
    p_category := null;
    p_passage := null;
    p_title := meta->>'senior_title';
    if p_title not in ('Dr','Pr') then p_title := 'Dr'; end if;
  end if;

  if p_first is not null and p_last is not null then
    p_display := (case when p_role = 'senior' then p_title else 'Dr' end)
                 || ' ' || p_first || ' ' || p_last;
  else
    p_display := btrim(coalesce(meta->>'display_name',''));
    if char_length(p_display) not between 3 and 160 then p_display := 'Médecin en attente'; end if;
  end if;

  insert into public.doctor_profiles
    (user_id,display_name,first_name,last_name,requested_role,junior_category,internship_passage,senior_title)
  values
    (new.id,p_display,p_first,p_last,p_role,p_category,p_passage,p_title)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

revoke all on function viscera_private.register_doctor_profile()
  from public, anon, authenticated;
