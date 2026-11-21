-- =========================================================
-- LOOZ — Migration 018: the photo diagnosis can use GEMINI (Google)
--
-- The Edge Function "diagnose" asks the model named in the setting
-- app_settings.diagnosis_model:
--   'roboflow'                     Roboflow (the secret ROBOFLOW_MODEL, as before)
--   'roboflow:<project>/<version>' another Roboflow model
--   'gemini:gemini-3.6-flash'      Gemini vision (the secret GEMINI_VISION_API_KEY,
--                                  Google project "looz-vision")
-- Changing it needs no new app and no new deployment (Table Editor or SQL).
-- The app gets the same codes as before (likely / unsure / nothing).
--
-- With Gemini, when Google refuses (limit, busy, too slow, key), the function
-- tries the backup Gemini key (secret GEMINI_API_KEY2), then a 3rd model on
-- GROQ named in app_settings.diagnosis_groq_model ('qwen/qwen3.8-27b'; empty
-- = no Groq step; the secret GROQ_API_KEY). Groq's answers are saved as
-- 'groq:<model>' and judged like Gemini's.
--
-- Gemini gives ONE answer (shot_hole, leaf_curl, leaf_spot, none or
-- not_a_leaf), its own confidence, the plant it sees and approximate boxes.
-- Its confidence is not a measured probability and our test set was small,
-- so the verdict is CONSERVATIVE:
--   likely ("على الأرجح") only when ALL of these are true:
--     confidence >= diagnosis_gemini_likely (0.90), at least one box (the
--     sign is located), and the plant is almond (or it can't tell);
--   unsure ("غير متأكد") from diagnosis_gemini_unsure (0.70);
--   nothing ("لم نجد") below, or when Gemini sees no disease / no leaf.
-- The same for Groq's answers. Roboflow keeps its own thresholds (diagnosis_likely 0.65, diagnosis_unsure 0.40).
--
-- What this file adds:
--   1. Settings: the model, the Google free-tier switch (the camera screen
--      says "Google may use it to improve its services" while it is true),
--      the 2 Gemini thresholds, the Groq model (3rd step), and 15 photos
--      per day for the whole app (Gemini free tier: 5 per minute, 20 per
--      day; 10 per farmer is kept).
--      Groq's free tier for qwen/qwen3.8-27b (19 Nov 2026): 1,000 requests
--      a day, 7,000 input tokens a minute (about 3 photos a minute).
--   2. photo_diagnoses: Gemini's own answer and plant (codes), a detection
--      may have no box, the new error "model_busy" (Google busy).
--   3. diagnosis_finish (the conservative verdict) and my_diagnosis_quota
--      (+ google, google_free_tier for the camera screen's text).
--   4. Last check.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 017. Safe to run again: the settings you changed
-- are kept (15 photos a day is set only over the old default of 1000).
-- =========================================================


-- ---------- 1) Settings (admin) ----------
alter table app_settings add column if not exists diagnosis_model            text    not null default 'roboflow';
alter table app_settings add column if not exists diagnosis_google_free_tier boolean not null default true;
alter table app_settings add column if not exists diagnosis_gemini_likely    real    not null default 0.90;
alter table app_settings add column if not exists diagnosis_gemini_unsure    real    not null default 0.70;
alter table app_settings add column if not exists diagnosis_groq_model       text    not null default 'qwen/qwen3.8-27b';
alter table app_settings drop constraint if exists app_settings_diagnosis_gemini_check;
alter table app_settings add constraint app_settings_diagnosis_gemini_check check (
  diagnosis_model ~ '^(roboflow(:[a-z0-9][a-z0-9-]{0,80}/[0-9]{1,4})?|gemini:[a-z0-9][a-z0-9.-]{0,60})$'
  and diagnosis_groq_model ~ '^([a-z0-9][a-z0-9._-]{0,40}/)?[a-z0-9][a-z0-9._:-]{0,60}$|^$'
  and diagnosis_gemini_unsure > 0 and diagnosis_gemini_unsure < diagnosis_gemini_likely
  and diagnosis_gemini_likely <= 1);
comment on column app_settings.diagnosis_model is
  'The model of the photo diagnosis: roboflow (secret ROBOFLOW_MODEL), roboflow:<project>/<version>, or gemini:<model> (secret GEMINI_VISION_API_KEY).';
comment on column app_settings.diagnosis_google_free_tier is
  'true while the Gemini API of the photos is on Google''s FREE tier (Google may use the photos): the camera screen says so. false after the paid tier.';
comment on column app_settings.diagnosis_gemini_likely is
  'Gemini: its confidence from which the app says "probably" (also needs a box and an almond leaf).';
comment on column app_settings.diagnosis_gemini_unsure is
  'Gemini: its confidence from which the app says "not sure"; below: "we did not find".';
comment on column app_settings.diagnosis_groq_model is
  'The 3rd step when Gemini refuses: this model on Groq (secret GROQ_API_KEY), e.g. qwen/qwen3.8-27b. Empty = no Groq step.';
comment on column app_settings.diagnosis_app_per_day is
  'Photos the whole app may send per day: protects the model''s limits (Gemini free tier: 20 per day).';

-- Gemini's free tier allows 20 photos a day: 15 leaves room for the tries
-- again. Only over the old default (1000): a value you chose is kept.
update app_settings set diagnosis_app_per_day = 15 where id and diagnosis_app_per_day = 1000;


-- ---------- 2) The diagnoses: Gemini's own answer ----------
alter table photo_diagnoses add column if not exists model_label text;
alter table photo_diagnoses add column if not exists plant       text;
alter table photo_diagnoses drop constraint if exists photo_diagnoses_model_label_check;
alter table photo_diagnoses add constraint photo_diagnoses_model_label_check check (
  model_label is null or model_label in ('shot_hole', 'leaf_curl', 'leaf_spot', 'none', 'not_a_leaf'));
alter table photo_diagnoses drop constraint if exists photo_diagnoses_plant_check;
alter table photo_diagnoses add constraint photo_diagnoses_plant_check check (
  plant is null or plant in ('almond', 'olive', 'other', 'unknown'));
alter table photo_diagnoses drop constraint if exists photo_diagnoses_error_check;
alter table photo_diagnoses add constraint photo_diagnoses_error_check check (
  error is null or error in ('bad_image', 'storage', 'model_error', 'model_quota', 'model_timeout', 'model_busy'));
comment on column photo_diagnoses.model_label is
  'Gemini only: its own answer (shot_hole, leaf_curl, leaf_spot, none, not_a_leaf). null for Roboflow.';
comment on column photo_diagnoses.plant is
  'Gemini only: the plant it sees (almond, olive, other, unknown). null for Roboflow.';
comment on column photo_diagnoses.detections is
  '[{"class": "shot_hole", "confidence": 0.81, "box": [x0, y0, x1, y1] or null}] (fractions of the photo, most sure first; Gemini may give no box).';


-- ---------- 3) The functions ----------
-- The Edge Function, AFTER the model answered (or failed). p_result:
--   {"status": "done", "model": "roboflow:almond-diseases-detection-l7tfx/2",
--    "detections": [{"class": "shot_hole", "confidence": 0.81, "box": [0.1, 0.2, 0.3, 0.4]}]}
--   {"status": "done", "model": "gemini:gemini-3.6-flash", "label": "shot_hole", "plant": "almond",
--    "detections": [{"class": "shot_hole", "confidence": 0.92, "box": [0.1, 0.2, 0.3, 0.4] or null}]}
--   {"status": "failed", "error": "model_error" | "model_quota" | "model_timeout" | "model_busy" | "storage" | "bad_image"}
-- The verdict comes from the settings (one place), see the top of this file.
create or replace function public.diagnosis_finish(p_id uuid, p_result jsonb)
returns photo_diagnoses
language plpgsql security definer set search_path = public as $$
declare
  s       app_settings;
  d       photo_diagnoses;
  det     jsonb;
  item    jsonb;
  box     jsonb;
  list    jsonb := '[]'::jsonb;
  top     jsonb;
  conf    double precision;
  top_c   numeric;
  gemini  boolean;  -- Gemini or Groq: the conservative verdict
  v_label text := p_result ->> 'label';
  v_plant text := p_result ->> 'plant';
  has_box boolean;
  v_verdict text;
begin
  select * into d from photo_diagnoses where id = p_id for update;
  if d.id is null then
    raise exception 'Unknown diagnosis' using errcode = 'P0002';
  end if;
  if d.status <> 'pending' then
    raise exception 'This diagnosis is finished' using errcode = '22023';
  end if;
  if jsonb_typeof(p_result) is distinct from 'object' then
    raise exception 'An object expected' using errcode = '22023';
  end if;

  if p_result ->> 'status' = 'failed' then
    if coalesce(p_result ->> 'error', '') not in
       ('bad_image', 'storage', 'model_error', 'model_quota', 'model_timeout', 'model_busy') then
      raise exception 'Error: bad_image, storage, model_error, model_quota, model_timeout or model_busy'
        using errcode = '22023';
    end if;
    update photo_diagnoses set status = 'failed', error = p_result ->> 'error', finished_at = now()
    where id = p_id returning * into d;
    return d;
  end if;
  if p_result ->> 'status' is distinct from 'done' then
    raise exception 'Status: done or failed' using errcode = '22023';
  end if;
  if coalesce(p_result ->> 'model', '') !~ '^[a-z0-9][a-z0-9:/._-]{0,99}$' then
    raise exception 'Model: a short code' using errcode = '22023';
  end if;
  gemini := (p_result ->> 'model') like 'gemini:%' or (p_result ->> 'model') like 'groq:%';
  if v_label is not null and v_label not in ('shot_hole', 'leaf_curl', 'leaf_spot', 'none', 'not_a_leaf') then
    raise exception 'Label: shot_hole, leaf_curl, leaf_spot, none or not_a_leaf' using errcode = '22023';
  end if;
  if v_plant is not null and v_plant not in ('almond', 'olive', 'other', 'unknown') then
    raise exception 'Plant: almond, olive, other or unknown' using errcode = '22023';
  end if;
  det := coalesce(p_result -> 'detections', '[]'::jsonb);
  if jsonb_typeof(det) <> 'array' or jsonb_array_length(det) > 300 then
    raise exception 'Detections: a list (300 at most)' using errcode = '22023';
  end if;

  -- Each detection: a known class, a confidence 0..1, and a box [x0, y0, x1, y1]
  -- inside the photo, or no box (null). Kept: codes and numbers only.
  for item in select * from jsonb_array_elements(det) loop
    box := item -> 'box';
    if jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'class', '') <> all (public.diagnosis_classes())
       or jsonb_typeof(item -> 'confidence') is distinct from 'number'
       or (box is not null and jsonb_typeof(box) <> 'null'
           and (jsonb_typeof(box) <> 'array' or jsonb_array_length(box) <> 4
                or exists (select 1 from jsonb_array_elements(box) v where jsonb_typeof(v) <> 'number')))
    then
      raise exception 'Bad detection: %', left(item::text, 80) using errcode = '22023';
    end if;
    if jsonb_typeof(box) = 'null' then
      box := null;
    end if;
    conf := (item ->> 'confidence')::double precision;
    if conf < 0 or conf > 1
       or (box is not null
           and ((box ->> 0)::double precision < 0 or (box ->> 1)::double precision < 0
                or (box ->> 2)::double precision > 1 or (box ->> 3)::double precision > 1
                or (box ->> 0)::double precision >= (box ->> 2)::double precision
                or (box ->> 1)::double precision >= (box ->> 3)::double precision)) then
      raise exception 'Bad detection: %', left(item::text, 80) using errcode = '22023';
    end if;
    list := list || jsonb_build_array(jsonb_build_object(
      'class', item ->> 'class',
      'confidence', round(conf::numeric, 3),
      'box', case when box is null then null
                  else jsonb_build_array(round((box ->> 0)::numeric, 4), round((box ->> 1)::numeric, 4),
                                         round((box ->> 2)::numeric, 4), round((box ->> 3)::numeric, 4)) end));
  end loop;
  -- Gemini saw no disease (or no leaf): nothing, whatever the list says.
  if gemini and v_label in ('none', 'not_a_leaf') then
    list := '[]'::jsonb;
  end if;
  -- The most sure first; 50 at most.
  select coalesce(jsonb_agg(x order by (x ->> 'confidence')::numeric desc), '[]'::jsonb) into list
  from (select x from jsonb_array_elements(list) x
        order by (x ->> 'confidence')::numeric desc limit 50) t;
  top := list -> 0;
  top_c := (top ->> 'confidence')::numeric;
  has_box := exists (select 1 from jsonb_array_elements(list) x
                     where x ->> 'class' = top ->> 'class' and jsonb_typeof(x -> 'box') = 'array');

  select * into s from app_settings where id;
  v_verdict := case
    when top is null then 'nothing'
    when gemini then case
      when top_c >= s.diagnosis_gemini_likely and has_box and coalesce(v_plant, 'unknown') in ('almond', 'unknown')
        then 'likely'
      when top_c >= s.diagnosis_gemini_unsure then 'unsure'
      else 'nothing' end
    when top_c >= s.diagnosis_likely then 'likely'
    when top_c >= s.diagnosis_unsure then 'unsure'
    else 'nothing' end;

  update photo_diagnoses set
    status         = 'done',
    model          = p_result ->> 'model',
    model_label    = v_label,
    plant          = v_plant,
    detections     = list,
    top_class      = top ->> 'class',
    top_confidence = top_c::real,
    verdict        = v_verdict,
    finished_at    = now()
  where id = p_id returning * into d;
  return d;
end;
$$;

-- The app, before the camera: is it on, how many photos are left today, and
-- does the photo go to Google (the camera screen says so)?
create or replace function public.my_diagnosis_quota() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'enabled', s.diagnosis_enabled,
    'paid', public.has_paid_pack(auth.uid()),
    'per_day', s.diagnosis_per_day,
    'used_today', public.diagnosis_count_today(auth.uid()),
    'google', s.diagnosis_model like 'gemini:%',
    'google_free_tier', s.diagnosis_model like 'gemini:%' and s.diagnosis_google_free_tier)
  from app_settings s where s.id and auth.uid() is not null;
$$;

revoke all on function public.diagnosis_finish(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.my_diagnosis_quota()          from public, anon;
grant execute on function public.diagnosis_finish(uuid, jsonb) to service_role;
grant execute on function public.my_diagnosis_quota()          to authenticated, service_role;


-- ---------- 4) Last check: you should see  true | false | roboflow | true | 10 | 15 | 0.9 | 0.7 | qwen/qwen3.8-27b ----------
--   ready          true  = the new columns are there
--   app_can_finish false = only the Edge Function finishes a diagnosis
--   then: the model (roboflow until you switch to Gemini), the Google free-tier
--   switch, photos per farmer per day, per day for the whole app, the 2 Gemini
--   thresholds, the Groq model of the 3rd step (empty = none)
select
  exists (select 1 from information_schema.columns
          where table_schema = 'public' and table_name = 'photo_diagnoses' and column_name = 'plant') as ready,
  has_function_privilege('authenticated', 'public.diagnosis_finish(uuid, jsonb)', 'execute')        as app_can_finish,
  s.diagnosis_model, s.diagnosis_google_free_tier, s.diagnosis_per_day, s.diagnosis_app_per_day,
  s.diagnosis_gemini_likely, s.diagnosis_gemini_unsure, s.diagnosis_groq_model
from app_settings s where s.id;
