-- =========================================================
-- LOOZ — Migration 016: photo diagnosis (Bêta) for the paid pack
--
-- A paid farmer photographs an almond leaf. The app sends the photo to the
-- Edge Function "diagnose", which (with the service_role key):
--   1. diagnosis_begin(user, zone): checks the paid pack, the switch and the
--      limits of the day, and makes a "pending" diagnosis with the name of
--      its photo (bucket "diagnoses", folder = the farmer's id);
--   2. saves the photo in the private bucket "diagnoses";
--   3. asks the model (Roboflow, almond-diseases-detection-l7tfx/2);
--   4. diagnosis_finish(id, result): checks and saves the CODES only
--      (shot_hole / leaf_curl / leaf_spot, confidence, boxes) and decides
--      the verdict with the thresholds below: likely / unsure / nothing.
-- Nobody writes a diagnosis or a diagnosis photo from the app: farmers only
-- READ their own (history), admins read all (the demo admin: demo accounts).
--
-- What this file adds:
--   1. Settings (admin): on / off, photos per farmer per day (10), photos
--      per day for the whole app (1000: the Roboflow credits), photos kept
--      per farmer (30, older photos are deleted, their result stays), the
--      two thresholds (0.65 "likely", 0.40 "unsure").
--   2. Table photo_diagnoses + the 3 class codes.
--   3. diagnosis_begin / diagnosis_finish (service_role only),
--      my_diagnosis_quota() and diagnosis_link_post() for the app.
--   4. The rules (RLS) and the private bucket "diagnoses" (5 MB, JPEG).
--   5. Last check.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 015. Safe to run again.
-- (If you run 014 again after this file, its 2nd number is 28, not 26: the
--  2 reading rules of this file use admin_sees_all() too.)
-- =========================================================


-- ---------- 1) Settings (admin) ----------
alter table app_settings add column if not exists diagnosis_enabled     boolean not null default true;
alter table app_settings add column if not exists diagnosis_per_day     integer not null default 10;
alter table app_settings add column if not exists diagnosis_app_per_day integer not null default 1000;
alter table app_settings add column if not exists diagnosis_keep_photos integer not null default 30;
alter table app_settings add column if not exists diagnosis_likely      real    not null default 0.65;
alter table app_settings add column if not exists diagnosis_unsure      real    not null default 0.40;
alter table app_settings drop constraint if exists app_settings_diagnosis_check;
alter table app_settings add constraint app_settings_diagnosis_check check (
  diagnosis_per_day between 1 and 100
  and diagnosis_app_per_day between 1 and 100000
  and diagnosis_keep_photos between 1 and 1000
  and diagnosis_unsure > 0 and diagnosis_unsure < diagnosis_likely and diagnosis_likely <= 1);
comment on column app_settings.diagnosis_enabled is 'false = the photo diagnosis is off (the app says so).';
comment on column app_settings.diagnosis_per_day is 'Photos one farmer may send per day (Tunisia time).';
comment on column app_settings.diagnosis_app_per_day is 'Photos the whole app may send per day: protects the Roboflow credits.';
comment on column app_settings.diagnosis_keep_photos is 'Photos kept per farmer (the newest). Older photos are deleted; their result stays.';
comment on column app_settings.diagnosis_likely is 'Confidence from which the app says "probably" (0 to 1).';
comment on column app_settings.diagnosis_unsure is 'Confidence from which the app says "not sure"; below: "we did not find".';


-- ---------- 2) The diagnoses ----------
create or replace function public.diagnosis_classes() returns text[]
language sql immutable as $$
  select array['shot_hole', 'leaf_curl', 'leaf_spot'];
$$;

create table if not exists photo_diagnoses (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  zone_id         uuid references zones(id) on delete set null,
  photo_path      text check (photo_path is null or photo_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'),
  status          text not null default 'pending' check (status in ('pending', 'done', 'failed')),
  model           text check (model is null or model ~ '^[a-z0-9][a-z0-9:/._-]{0,99}$'),
  verdict         text check (verdict is null or verdict in ('likely', 'unsure', 'nothing')),
  top_class       text check (top_class is null or top_class = any (public.diagnosis_classes())),
  top_confidence  real check (top_confidence is null or top_confidence between 0 and 1),
  detections      jsonb not null default '[]'::jsonb check (jsonb_typeof(detections) = 'array'),
  error           text check (error is null or error in ('bad_image', 'storage', 'model_error', 'model_quota', 'model_timeout')),
  post_id         uuid references posts(id) on delete set null,
  created_at      timestamptz not null default now(),
  finished_at     timestamptz,
  constraint photo_diagnoses_state check (
    (status = 'pending' and verdict is null and error is null)
    or (status = 'done' and verdict is not null and error is null)
    or (status = 'failed' and verdict is null and error is not null))
);
create index if not exists photo_diagnoses_user_idx on photo_diagnoses (user_id, created_at desc);
create index if not exists photo_diagnoses_day_idx on photo_diagnoses (created_at);
comment on table photo_diagnoses is
  'Photo diagnoses (Bêta): codes only (class, confidence, boxes 0..1). Written only by the Edge Function "diagnose".';
comment on column photo_diagnoses.detections is
  '[{"class": "shot_hole", "confidence": 0.81, "box": [x0, y0, x1, y1]}] (fractions of the photo, most sure first).';

-- A farmer with a running paid pack (like user_plan(), for any user).
create or replace function public.has_paid_pack(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from subscriptions
                 where user_id = p_user and status = 'active'
                   and (ends_at is null or ends_at > now())
                   and coalesce(public.plan_rank(plan), 0) >= 1);
$$;

-- Photos counted in a day (Tunisia time): done, or still being diagnosed
-- (a diagnosis that failed is not counted).
create or replace function public.diagnosis_count_today(p_user uuid default null) returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::integer from photo_diagnoses
  where created_at >= (date_trunc('day', now() at time zone 'Africa/Tunis') at time zone 'Africa/Tunis')
    and (p_user is null or user_id = p_user)
    and (status = 'done' or (status = 'pending' and created_at > now() - interval '2 minutes'));
$$;


-- ---------- 3) The functions ----------
-- The Edge Function, BEFORE the photo is saved and sent to the model.
-- Returns {"id", "photo_path", "remove": [old photo paths to delete],
--          "per_day", "used_today"}.
-- Errors: P0002 unknown user, PT403 no paid pack, PT503 off / app limit of
-- the day, PT429 the farmer's limit of the day, 22023 not his zone.
create or replace function public.diagnosis_begin(p_user uuid, p_zone uuid default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s       app_settings;
  used    integer;
  d       photo_diagnoses;
  removed text[];
begin
  if p_user is null or not exists (select 1 from profiles where id = p_user) then
    raise exception 'Unknown user' using errcode = 'P0002';
  end if;
  select * into s from app_settings where id;
  if not coalesce(s.diagnosis_enabled, false) then
    raise exception 'Photo diagnosis is off' using errcode = 'PT503';
  end if;
  if not public.has_paid_pack(p_user) then
    raise exception 'Paid pack only' using errcode = 'PT403';
  end if;
  if p_zone is not null and not exists (
       select 1 from zones z join orchards o on o.id = z.orchard_id
       where z.id = p_zone and o.farmer_id = p_user and z.archived_at is null) then
    raise exception 'Not a zone of this farmer' using errcode = '22023';
  end if;
  -- One at a time per farmer: two photos sent together can't pass the limit.
  perform pg_advisory_xact_lock(hashtext('diagnosis:' || p_user::text));
  used := public.diagnosis_count_today(p_user);
  if used >= s.diagnosis_per_day then
    raise exception 'Too many photos today' using errcode = 'PT429';
  end if;
  if public.diagnosis_count_today(null) >= s.diagnosis_app_per_day then
    raise exception 'App limit of the day reached' using errcode = 'PT503';
  end if;

  insert into photo_diagnoses (user_id, zone_id) values (p_user, p_zone) returning * into d;
  update photo_diagnoses set photo_path = p_user::text || '/' || d.id::text || '.jpg'
  where id = d.id returning * into d;

  -- Keep the photos of the newest diagnoses only: the older photos are given
  -- back to be deleted from the bucket (their result stays).
  with old as (
    select id, photo_path from photo_diagnoses
    where user_id = p_user and photo_path is not null
    order by created_at desc, id
    offset s.diagnosis_keep_photos
  ), cleared as (
    update photo_diagnoses x set photo_path = null from old where x.id = old.id returning old.photo_path
  )
  select coalesce(array_agg(photo_path), '{}') into removed from cleared;

  return jsonb_build_object('id', d.id, 'photo_path', d.photo_path, 'remove', to_jsonb(removed),
                            'per_day', s.diagnosis_per_day, 'used_today', used + 1);
end;
$$;

-- The Edge Function, AFTER the model answered (or failed). p_result:
--   {"status": "done", "model": "roboflow:almond-diseases-detection-l7tfx/2",
--    "detections": [{"class": "shot_hole", "confidence": 0.81, "box": [0.1, 0.2, 0.3, 0.4]}]}
--   {"status": "failed", "error": "model_error" | "model_quota" | "model_timeout" | "storage" | "bad_image"}
-- The verdict comes from the thresholds of app_settings (one place).
create or replace function public.diagnosis_finish(p_id uuid, p_result jsonb)
returns photo_diagnoses
language plpgsql security definer set search_path = public as $$
declare
  s     app_settings;
  d     photo_diagnoses;
  det   jsonb;
  item  jsonb;
  box   jsonb;
  list  jsonb := '[]'::jsonb;
  top   jsonb;
  conf  double precision;
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
    if coalesce(p_result ->> 'error', '') not in ('bad_image', 'storage', 'model_error', 'model_quota', 'model_timeout') then
      raise exception 'Error: bad_image, storage, model_error, model_quota or model_timeout' using errcode = '22023';
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
  det := coalesce(p_result -> 'detections', '[]'::jsonb);
  if jsonb_typeof(det) <> 'array' or jsonb_array_length(det) > 300 then
    raise exception 'Detections: a list (300 at most)' using errcode = '22023';
  end if;

  -- Each detection: a known class, a confidence 0..1, a box [x0, y0, x1, y1]
  -- inside the photo. Kept: codes and numbers only.
  for item in select * from jsonb_array_elements(det) loop
    box := item -> 'box';
    if jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'class', '') <> all (public.diagnosis_classes())
       or jsonb_typeof(item -> 'confidence') <> 'number'
       or jsonb_typeof(box) <> 'array' or jsonb_array_length(box) <> 4
       or exists (select 1 from jsonb_array_elements(box) v where jsonb_typeof(v) <> 'number')
    then
      raise exception 'Bad detection: %', left(item::text, 80) using errcode = '22023';
    end if;
    conf := (item ->> 'confidence')::double precision;
    if conf < 0 or conf > 1
       or (box ->> 0)::double precision < 0 or (box ->> 1)::double precision < 0
       or (box ->> 2)::double precision > 1 or (box ->> 3)::double precision > 1
       or (box ->> 0)::double precision >= (box ->> 2)::double precision
       or (box ->> 1)::double precision >= (box ->> 3)::double precision then
      raise exception 'Bad detection: %', left(item::text, 80) using errcode = '22023';
    end if;
    list := list || jsonb_build_array(jsonb_build_object(
      'class', item ->> 'class',
      'confidence', round(conf::numeric, 3),
      'box', jsonb_build_array(round((box ->> 0)::numeric, 4), round((box ->> 1)::numeric, 4),
                               round((box ->> 2)::numeric, 4), round((box ->> 3)::numeric, 4))));
  end loop;
  -- The most sure first; 50 at most.
  select coalesce(jsonb_agg(x order by (x ->> 'confidence')::numeric desc), '[]'::jsonb) into list
  from (select x from jsonb_array_elements(list) x
        order by (x ->> 'confidence')::numeric desc limit 50) t;
  top := list -> 0;

  select * into s from app_settings where id;
  update photo_diagnoses set
    status         = 'done',
    model          = p_result ->> 'model',
    detections     = list,
    top_class      = top ->> 'class',
    top_confidence = (top ->> 'confidence')::real,
    verdict        = case when top is null then 'nothing'
                          when (top ->> 'confidence')::numeric >= s.diagnosis_likely then 'likely'
                          when (top ->> 'confidence')::numeric >= s.diagnosis_unsure then 'unsure'
                          else 'nothing' end,
    finished_at    = now()
  where id = p_id returning * into d;
  return d;
end;
$$;

-- The app, before the camera: is it on, and how many photos are left today?
create or replace function public.my_diagnosis_quota() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'enabled', s.diagnosis_enabled,
    'paid', public.has_paid_pack(auth.uid()),
    'per_day', s.diagnosis_per_day,
    'used_today', public.diagnosis_count_today(auth.uid()))
  from app_settings s where s.id and auth.uid() is not null;
$$;

-- "اسأل خبيرًا": the community question made from the diagnosis (both
-- must be the farmer's own).
create or replace function public.diagnosis_link_post(p_diagnosis uuid, p_post uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if not exists (select 1 from posts where id = p_post and author_id = auth.uid()) then
    raise exception 'Not your question' using errcode = 'P0002';
  end if;
  update photo_diagnoses set post_id = p_post where id = p_diagnosis and user_id = auth.uid();
  if not found then
    raise exception 'Not your diagnosis' using errcode = 'P0002';
  end if;
end;
$$;


-- ---------- 4) The rules (RLS), the rights and the bucket ----------
alter table photo_diagnoses enable row level security;
drop policy if exists "Farmers see their own diagnoses" on photo_diagnoses;
create policy "Farmers see their own diagnoses" on photo_diagnoses for select to authenticated
  using (user_id = (select auth.uid()) or (select public.admin_sees_all())
         or ((select public.is_demo_admin()) and user_id = any ((select public.demo_person_ids())::uuid[])));

revoke all on photo_diagnoses from anon, authenticated;
grant select on photo_diagnoses to authenticated;
grant all on photo_diagnoses to service_role;

revoke all on function public.diagnosis_classes()                  from public, anon;
revoke all on function public.has_paid_pack(uuid)                  from public, anon, authenticated;
revoke all on function public.diagnosis_count_today(uuid)          from public, anon, authenticated;
revoke all on function public.diagnosis_begin(uuid, uuid)          from public, anon, authenticated;
revoke all on function public.diagnosis_finish(uuid, jsonb)        from public, anon, authenticated;
revoke all on function public.my_diagnosis_quota()                 from public, anon;
revoke all on function public.diagnosis_link_post(uuid, uuid)      from public, anon;
grant execute on function public.diagnosis_classes(), public.my_diagnosis_quota(),
  public.diagnosis_link_post(uuid, uuid) to authenticated, service_role;
grant execute on function public.has_paid_pack(uuid), public.diagnosis_count_today(uuid),
  public.diagnosis_begin(uuid, uuid), public.diagnosis_finish(uuid, jsonb) to service_role;

-- The private bucket of the diagnosis photos: 5 MB, JPEG only. Names:
-- <farmer id>/<diagnosis id>.jpg. Only the Edge Function writes and deletes
-- (service_role): no insert / update / delete rule for users.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('diagnoses', 'diagnoses', false, 5242880, array['image/jpeg'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Diagnosis photos: see your own" on storage.objects;
create policy "Diagnosis photos: see your own"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'diagnoses'
    and ((storage.foldername(name))[1] = (select auth.uid()::text)
         or (select public.admin_sees_all())
         or ((select public.is_demo_admin())
             and (storage.foldername(name))[1] = any ((select public.demo_person_ids())::text[])))
  );


-- ---------- 5) Last check: you should see  true | false | false | true | 10 | 1000 | 0.65 | 0.4 ----------
--   rules_on            true  = the table has its rules (RLS)
--   app_can_write       false = only the Edge Function writes diagnoses
--   app_can_begin       false = the app can't start a diagnosis by itself
--   bucket_ready        true  = private bucket "diagnoses", 5 MB, JPEG
--   then the settings: photos per farmer per day, per day for the app, the 2 thresholds
select
  (select relrowsecurity from pg_class where oid = 'public.photo_diagnoses'::regclass)                as rules_on,
  has_table_privilege('authenticated', 'public.photo_diagnoses', 'insert')
    or has_table_privilege('authenticated', 'public.photo_diagnoses', 'update')                     as app_can_write,
  has_function_privilege('authenticated', 'public.diagnosis_begin(uuid, uuid)', 'execute')          as app_can_begin,
  exists (select 1 from storage.buckets where id = 'diagnoses' and public = false
          and file_size_limit = 5242880 and allowed_mime_types = array['image/jpeg'])               as bucket_ready,
  s.diagnosis_per_day, s.diagnosis_app_per_day, s.diagnosis_likely, s.diagnosis_unsure
from app_settings s where s.id;
