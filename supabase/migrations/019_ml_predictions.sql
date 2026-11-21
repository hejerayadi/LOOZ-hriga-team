-- =========================================================
-- LOOZ — Migration 019: the two ML models (frost + stress) in the app
--
-- What it does:
--   1. Settings (admin): ml_enabled, ml_notify_enabled, ml_explain_enabled,
--      ml_groq_model, ml_likely_min.
--   2. FARM CONTEXT that the models need, on each zone (soil type and its
--      FC / WP / SAT, irrigation system, irrigation water EC, ground cover,
--      position low / mid / high, cover crop, root depth, start of bloom,
--      a stage set by hand) and on the orchard (elevation). Empty = a
--      default (from the zone type of the designer, the farmer's answers
--      and his governorate): ml_zone_context() gives the values used and
--      which ones are defaults. The IoT demo orchard (22 777 001) is filled.
--   3. Three new RAW channels of the sensor boxes (Node-RED): light_adc
--      (light sensor, 0..4095), piezo_rms and piezo_events_h (the piezo on
--      the trunk). iot_ingest() saves them (history + latest).
--   4. The predictions (written ONLY by the ML worker, see 6):
--        ml_latest        the last prediction of each box and model
--        ml_history       a point when the state changes, else 1 per hour
--                         of measured time (kept iot_history_days, like
--                         the readings)
--        ml_notifications the IN-APP notifications: one per problem (no
--                         repeat for the same problem), read / resolved
--      CODES only (states, factors) + the explanation texts of Groq (or
--      nothing: the app then writes a text from the codes).
--   5. Only PAID farmers read their predictions (RLS); admins read all, the
--      demo admin only the demo boxes. The app marks a notification read
--      with ml_notification_mark().
--   6. The ML WORKER (Python, dashboard/backend/ml) has its own secret KEY
--      (like a gateway): only its hash is here. ml_worker_jobs(),
--      ml_worker_history() and ml_worker_save() check the key themselves:
--      no service_role key is needed anywhere. New key:
--      select public.ml_worker_new_key('ML-01');
--   7. Supabase Realtime: node_latest, ml_latest and ml_notifications are
--      sent to the app as soon as they change (with the same rules).
--   8. Last check.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 018. Safe to run again (each statement can be run
-- alone, your settings and the context you typed are kept).
-- If you run 014 again after it, 014's second number is 34 (not 30).
-- =========================================================


-- ---------- 1) Settings (admin) ----------
alter table app_settings add column if not exists ml_enabled         boolean not null default true;
alter table app_settings add column if not exists ml_notify_enabled  boolean not null default true;
alter table app_settings add column if not exists ml_explain_enabled boolean not null default true;
alter table app_settings add column if not exists ml_groq_model      text    not null default 'qwen/qwen3.8-27b';
alter table app_settings add column if not exists ml_likely_min      real    not null default 0.6;
alter table app_settings drop constraint if exists app_settings_ml_groq_model_check;
alter table app_settings add constraint app_settings_ml_groq_model_check
  check (ml_groq_model = '' or ml_groq_model ~ '^[a-z0-9][a-z0-9._-]{0,60}(/[a-z0-9][a-z0-9._-]{0,60})?$');
alter table app_settings drop constraint if exists app_settings_ml_likely_min_check;
alter table app_settings add constraint app_settings_ml_likely_min_check check (ml_likely_min between 0.34 and 0.99);
comment on column app_settings.ml_enabled is 'false = the ML worker makes no new prediction (the app keeps the last ones).';
comment on column app_settings.ml_notify_enabled is 'false = no new in-app notification from the predictions.';
comment on column app_settings.ml_explain_enabled is 'false = no Groq text: the app writes a simple text from the codes.';
comment on column app_settings.ml_groq_model is 'Groq model of the explanations (Derja + French). Empty = no Groq.';
comment on column app_settings.ml_likely_min is 'From this probability the app says "على الأرجح" (else "غير متأكد").';


-- ---------- 2) The farm context ----------
alter table orchards add column if not exists elevation_m real;
alter table orchards drop constraint if exists orchards_elevation_m_check;
alter table orchards add constraint orchards_elevation_m_check check (elevation_m is null or elevation_m between -50 and 3000);
comment on column orchards.elevation_m is 'Altitude of the orchard in metres (empty = the usual one of the governorate).';

alter table zones add column if not exists soil_type               text;
alter table zones add column if not exists theta_fc                real;
alter table zones add column if not exists theta_wp                real;
alter table zones add column if not exists theta_sat               real;
alter table zones add column if not exists irrigation_system       text;
alter table zones add column if not exists irrigation_water_ec_dsm real;
alter table zones add column if not exists ground_cover_frac       real;
alter table zones add column if not exists node_position           text;
alter table zones add column if not exists cover_crop              boolean;
alter table zones add column if not exists root_depth_m            real;
alter table zones add column if not exists bloom_start             text;
alter table zones add column if not exists pheno_stage_override    text;
alter table zones drop constraint if exists zones_soil_type_check;
alter table zones add constraint zones_soil_type_check
  check (soil_type is null or soil_type in ('sand', 'loamy_sand', 'sandy_loam', 'loam', 'clay_loam', 'clay'));
alter table zones drop constraint if exists zones_theta_check;
alter table zones add constraint zones_theta_check check (
  (theta_fc is null or theta_fc between 0.02 and 0.6) and (theta_wp is null or theta_wp between 0.005 and 0.5)
  and (theta_sat is null or theta_sat between 0.2 and 0.7)
  and (theta_fc is null or theta_wp is null or theta_wp < theta_fc)
  and (theta_fc is null or theta_sat is null or theta_fc < theta_sat));
alter table zones drop constraint if exists zones_irrigation_system_check;
alter table zones add constraint zones_irrigation_system_check
  check (irrigation_system is null or irrigation_system in ('drip', 'rainfed', 'rainfed_supplemental'));
alter table zones drop constraint if exists zones_irrigation_water_ec_check;
alter table zones add constraint zones_irrigation_water_ec_check
  check (irrigation_water_ec_dsm is null or irrigation_water_ec_dsm between 0 and 20);
alter table zones drop constraint if exists zones_ground_cover_check;
alter table zones add constraint zones_ground_cover_check
  check (ground_cover_frac is null or ground_cover_frac between 0 and 1);
alter table zones drop constraint if exists zones_node_position_check;
alter table zones add constraint zones_node_position_check
  check (node_position is null or node_position in ('low', 'mid', 'high'));
alter table zones drop constraint if exists zones_root_depth_check;
alter table zones add constraint zones_root_depth_check check (root_depth_m is null or root_depth_m between 0.2 and 3);
alter table zones drop constraint if exists zones_bloom_start_check;
alter table zones add constraint zones_bloom_start_check
  check (bloom_start is null or bloom_start ~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$');
alter table zones drop constraint if exists zones_pheno_stage_override_check;
alter table zones add constraint zones_pheno_stage_override_check
  check (pheno_stage_override is null or pheno_stage_override in
         ('dormant', 'bloom', 'fruit_set', 'fruit_growth', 'kernel_fill', 'hull_split', 'postharvest', 'leaf_fall'));
comment on column zones.soil_type is 'Soil of the zone (empty = from the zone type: sandy_soil -> sand, else sandy_loam).';
comment on column zones.theta_fc is 'Water at field capacity (m3/m3). Empty = the usual value of the soil type.';
comment on column zones.irrigation_system is 'drip | rainfed | rainfed_supplemental (empty = from the zone type / the farmer''s answer).';
comment on column zones.irrigation_water_ec_dsm is 'Salt of the irrigation water (dS/m), if it was measured. Empty = unknown.';
comment on column zones.node_position is 'Where the box is: low (cold air collects there), mid, high.';
comment on column zones.bloom_start is 'Usual first day of bloom, MM-DD (empty = the usual one of the governorate).';
comment on column zones.pheno_stage_override is 'The stage of the trees set by hand (empty = from the date and bloom_start).';

-- The usual values of a governorate: latitude, altitude, first day of bloom.
create or replace function public.ml_governorate_defaults(p_code text)
returns table (latitude real, elevation_m real, bloom_start text)
language sql immutable as $$
  select v.lat::real, v.elev::real, v.bloom from (values
    ('tunis', 36.81, 10, '01-25'), ('ariana', 36.86, 20, '01-25'), ('ben_arous', 36.75, 20, '01-25'),
    ('manouba', 36.81, 30, '01-25'), ('nabeul', 36.45, 30, '01-25'), ('zaghouan', 36.40, 180, '02-01'),
    ('bizerte', 37.27, 10, '02-01'), ('beja', 36.73, 230, '02-05'), ('jendouba', 36.50, 140, '02-05'),
    ('kef', 36.17, 780, '02-20'), ('siliana', 36.08, 450, '02-15'), ('sousse', 35.83, 20, '01-20'),
    ('monastir', 35.77, 10, '01-20'), ('mahdia', 35.50, 10, '01-20'), ('sfax', 34.74, 20, '01-20'),
    ('kairouan', 35.68, 70, '02-01'), ('kasserine', 35.17, 680, '02-20'), ('sidi_bouzid', 35.04, 350, '02-05'),
    ('gabes', 33.88, 20, '01-15'), ('medenine', 33.35, 110, '01-15'), ('tataouine', 32.93, 240, '01-15'),
    ('gafsa', 34.43, 310, '02-01'), ('tozeur', 33.92, 50, '01-10'), ('kebili', 33.70, 40, '01-10'))
    as v(code, lat, elev, bloom)
  where v.code = coalesce(p_code, 'sfax')
  union all
  select 34.74::real, 20::real, '01-20' where coalesce(p_code, 'sfax') not in (
    'tunis', 'ariana', 'ben_arous', 'manouba', 'nabeul', 'zaghouan', 'bizerte', 'beja', 'jendouba', 'kef',
    'siliana', 'sousse', 'monastir', 'mahdia', 'sfax', 'kairouan', 'kasserine', 'sidi_bouzid', 'gabes',
    'medenine', 'tataouine', 'gafsa', 'tozeur', 'kebili');
$$;

-- The usual water of a soil type: field capacity, wilting point, saturation (m3/m3).
create or replace function public.ml_soil_defaults(p_soil text)
returns table (theta_fc real, theta_wp real, theta_sat real)
language sql immutable as $$
  select v.fc::real, v.wp::real, v.sat::real from (values
    ('sand', 0.12, 0.05, 0.43), ('loamy_sand', 0.174, 0.071, 0.43), ('sandy_loam', 0.25, 0.11, 0.44),
    ('loam', 0.30, 0.155, 0.46), ('clay_loam', 0.386, 0.238, 0.47), ('clay', 0.415, 0.27, 0.49))
    as v(soil, fc, wp, sat)
  where v.soil = coalesce(p_soil, 'sandy_loam');
$$;

-- The context the models use for a zone: the values typed (admin, later the
-- farmer) or the defaults, and the list of the defaults ("defaults").
create or replace function public.ml_zone_context(p_zone uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  z    zones;
  o    orchards;
  p    profiles;
  g    record;
  soil text;
  s    record;
  irr  text;
  cover real;
  dflt text[] := '{}';
begin
  select * into z from zones where id = p_zone;
  if z.id is null then
    return null;
  end if;
  select * into o from orchards where id = z.orchard_id;
  select * into p from profiles where id = o.farmer_id;
  select * into g from public.ml_governorate_defaults(p.zone);

  soil := z.soil_type;
  if soil is null then
    soil := case when z.zone_type = 'sandy_soil' then 'sand' else 'sandy_loam' end;
    dflt := array_append(dflt, 'soil_type');
  end if;
  select * into s from public.ml_soil_defaults(soil);
  if z.theta_fc is null or z.theta_wp is null or z.theta_sat is null then
    dflt := array_append(dflt, 'theta');
  end if;
  irr := z.irrigation_system;
  if irr is null then
    irr := case when z.zone_type = 'rainfed' then 'rainfed'
                when z.zone_type = 'irrigated' then 'drip'
                when p.irrigation = 'rainfed' then 'rainfed'
                else 'drip' end;
    dflt := array_append(dflt, 'irrigation_system');
  end if;
  cover := z.ground_cover_frac;
  if cover is null then
    cover := case when z.zone_type = 'young_trees' then 0.25 when z.zone_type = 'old_trees' then 0.6 else 0.45 end;
    dflt := array_append(dflt, 'ground_cover_frac');
  end if;
  if z.node_position is null then dflt := array_append(dflt, 'node_position'); end if;
  if z.cover_crop is null then dflt := array_append(dflt, 'cover_crop'); end if;
  if z.irrigation_water_ec_dsm is null then dflt := array_append(dflt, 'irrigation_water_ec_dsm'); end if;
  if z.bloom_start is null then dflt := array_append(dflt, 'bloom_start'); end if;
  if o.origin_lat is null then dflt := array_append(dflt, 'latitude'); end if;
  if o.elevation_m is null then dflt := array_append(dflt, 'elevation_m'); end if;

  return jsonb_build_object(
    'zone_id', z.id, 'governorate', coalesce(p.zone, 'sfax'),
    'soil_type', soil,
    'theta_fc', coalesce(z.theta_fc, s.theta_fc), 'theta_wp', coalesce(z.theta_wp, s.theta_wp),
    'theta_sat', coalesce(z.theta_sat, s.theta_sat),
    'irrigation_system', irr,
    'irrigation_water_ec_dsm', case when irr = 'drip' then z.irrigation_water_ec_dsm end,
    'ground_cover_frac', cover,
    'node_position', coalesce(z.node_position, 'mid'),
    'cover_crop', coalesce(z.cover_crop, false),
    'root_depth_m', coalesce(z.root_depth_m, 0.6),
    'bloom_start', coalesce(z.bloom_start, g.bloom_start),
    'pheno_stage_override', z.pheno_stage_override,
    'latitude', coalesce(o.origin_lat, g.latitude),
    'elevation_m', coalesce(o.elevation_m, g.elevation_m),
    'zone_type', z.zone_type,
    'defaults', to_jsonb(dflt));
end;
$$;

-- The IoT demo orchard (22 777 001, the Node-RED simulation): its context,
-- only where nothing was typed yet. Zone D is a low spot (frost scenario).
update zones z set
  soil_type         = coalesce(z.soil_type, v.soil),
  irrigation_system = coalesce(z.irrigation_system, 'drip'),
  irrigation_water_ec_dsm = coalesce(z.irrigation_water_ec_dsm, v.ec),
  ground_cover_frac = coalesce(z.ground_cover_frac, v.cover),
  node_position     = coalesce(z.node_position, v.pos),
  cover_crop        = coalesce(z.cover_crop, false),
  root_depth_m      = coalesce(z.root_depth_m, 0.6),
  bloom_start       = coalesce(z.bloom_start, '01-20')
from (values ('A', 'sandy_loam', null::real, 0.45::real, 'mid'), ('B', 'sandy_loam', 1.2, 0.5, 'mid'),
             ('C', 'loamy_sand', null, 0.55, 'high'), ('D', 'sand', null, 0.25, 'low'))
  as v(letter, soil, ec, cover, pos),
  orchards o, profiles p
where o.id = z.orchard_id and p.id = o.farmer_id and p.phone = '+21622777001' and o.is_demo
  and z.archived_at is null and z.letter = v.letter;

update orchards o set origin_lat = coalesce(o.origin_lat, 34.74), elevation_m = coalesce(o.elevation_m, 20)
from profiles p
where p.id = o.farmer_id and p.phone = '+21622777001' and o.is_demo;


-- ---------- 3) The raw channels of the boxes ----------
alter table node_latest   add column if not exists light_adc      smallint;
alter table node_latest   add column if not exists piezo_rms      real;
alter table node_latest   add column if not exists piezo_events_h real;
alter table node_readings add column if not exists light_adc      smallint;
alter table node_readings add column if not exists piezo_rms      real;
alter table node_readings add column if not exists piezo_events_h real;
comment on column node_readings.light_adc is 'Light sensor of the box, raw 12-bit value 0..4095 (saturates in full sun).';
comment on column node_readings.piezo_rms is 'Piezo on the trunk: RMS of the signal (vibration, wind).';
comment on column node_readings.piezo_events_h is 'Piezo on the trunk: acoustic events counted in the last hour.';

create or replace function public.iot_reading_problem(r jsonb) returns text
language plpgsql immutable as $$
declare
  lim record;
begin
  if jsonb_typeof(r) is distinct from 'object' then
    return 'not an object';
  end if;
  if coalesce(r ->> 'level', '') <> all (public.iot_levels()) then
    return 'level';
  end if;
  for lim in
    select * from (values
      ('soil_moisture_pct', -50, 150), ('soil_temp_c', -60, 100), ('air_temp_c', -60, 100),
      ('humidity_pct', -10, 110), ('light_par', -10, 5000), ('vpd_kpa', -1, 20),
      ('battery_pct', -10, 110), ('rssi_dbm', -200, 20), ('water_stress', 0, 100),
      ('heat_stress', 0, 100), ('anomaly', -10, 10), ('drying_rate_pct_h', -100, 100),
      ('hours_above_35c', 0, 48), ('confidence', 0, 1), ('packets_lost', 0, 1000000),
      ('seq', 0, 2147483647), ('light_adc', -10, 5000), ('piezo_rms', -1, 1000),
      ('piezo_events_h', 0, 100000)) as t(k, lo, hi)
  loop
    if jsonb_typeof(r -> lim.k) is not null and jsonb_typeof(r -> lim.k) <> 'null' then
      if jsonb_typeof(r -> lim.k) <> 'number' or (r ->> lim.k)::numeric not between lim.lo and lim.hi then
        return lim.k;
      end if;
    end if;
  end loop;
  return null;
end;
$$;

-- iot_ingest of 012, with the 3 new channels (everything else unchanged).
create or replace function public.iot_ingest(p_key_hash text, p_batch jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  gw          gateways;
  paid        boolean;
  keep_days   integer;
  r           jsonb;
  dev         text;
  t_meas      timestamptz;
  nid         uuid;
  n_installed timestamptz;
  z_archived  timestamptz;
  lat         node_latest;
  lvl         text;
  flt         text[];
  why         text;
  hist_at     timestamptz;
  accepted    integer := 0;
  stored      integer := 0;
  n_events    integer := 0;
  n_old       integer := 0;
  restarts    integer := 0;
  refused     jsonb := '{}';
  refused_dev jsonb := '{}';
  refused_box jsonb := '{}';
  touched     uuid[] := '{}';
  result      jsonb;
begin
  if p_key_hash is null or p_key_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Unknown gateway' using errcode = 'PT401';
  end if;
  select * into gw from gateways where key_hash = p_key_hash and enabled for update;
  if not found then
    raise exception 'Unknown gateway' using errcode = 'PT401';
  end if;
  if not coalesce((select s.iot_ingest_enabled from app_settings s where s.id), false) then
    raise exception 'The IoT ingest is turned off' using errcode = 'PT503';
  end if;
  if jsonb_typeof(p_batch) is distinct from 'object' or jsonb_typeof(p_batch -> 'readings') is distinct from 'array' then
    raise exception 'Bad batch: {"gateway": ..., "readings": [...]} expected' using errcode = '22023';
  end if;
  if p_batch ? 'gateway' and upper(p_batch ->> 'gateway') is distinct from gw.code then
    raise exception 'This key belongs to another gateway' using errcode = '22023';
  end if;
  if jsonb_array_length(p_batch -> 'readings') > 1000 then
    raise exception 'Too many readings in one batch (1000 at most)' using errcode = '22023';
  end if;

  keep_days := coalesce((select s.iot_history_days from app_settings s where s.id), 30);
  paid := exists (
    select 1 from orchards o join subscriptions s on s.user_id = o.farmer_id
    where o.id = gw.orchard_id and coalesce(public.plan_rank(s.plan), 0) >= 1 and s.status = 'active'
      and (s.ends_at is null or s.ends_at > now()));

  for r, dev, t_meas in
    select e.value, upper(btrim(e.value ->> 'device')), public.iot_time(e.value ->> 'measured_at')
    from jsonb_array_elements(p_batch -> 'readings') e
    order by 2, 3
  loop
    why := null;
    nid := null;
    if dev is null or dev !~ '^[A-Z0-9][A-Z0-9_-]{1,39}$' then
      why := 'bad_device';
      dev := null;
    else
      select n.id, n.installed_at, z.archived_at into nid, n_installed, z_archived
      from nodes n join zones z on z.id = n.zone_id
      where n.hardware_id = dev and z.orchard_id = gw.orchard_id;
      if nid is null then
        why := 'unknown_device';
      elsif z_archived is not null then
        why := 'zone_archived';
      elsif n_installed is null then
        why := 'not_installed';
      elsif not paid then
        why := 'no_paid_pack';
      elsif t_meas is null
         or (gw.time_mode = 'real' and (t_meas < now() - interval '7 days' or t_meas > now() + interval '10 minutes'))
         or (gw.time_mode = 'demo' and (t_meas < '2000-01-01' or t_meas > '2100-01-01')) then
        why := 'bad_time';
      elsif public.iot_reading_problem(r) is not null then
        why := 'bad_values';
      end if;
    end if;

    if why is not null then
      refused := refused || jsonb_build_object(why, coalesce((refused ->> why)::integer, 0) + 1);
      if dev is not null and (refused_dev ? dev or (select count(*) from jsonb_object_keys(refused_dev)) < 50) then
        refused_dev := refused_dev || jsonb_build_object(dev, why);
      end if;
      if nid is not null and why <> 'unknown_device' then
        refused_box := refused_box || jsonb_build_object(nid::text, why);
      end if;
      continue;
    end if;

    select * into lat from node_latest where node_id = nid;
    if lat.node_id is not null and gw.time_mode = 'demo' and t_meas < lat.measured_at - interval '1 day' then
      delete from node_readings where node_id = nid;
      delete from node_alert_events where node_id = nid;
      delete from node_fault_days where node_id = nid;
      delete from node_latest where node_id = nid;
      delete from ml_latest where node_id = nid;
      delete from ml_history where node_id = nid;
      lat := null;
      restarts := restarts + 1;
    end if;
    if lat.node_id is not null and t_meas <= lat.measured_at then
      n_old := n_old + 1;
      continue;
    end if;

    accepted := accepted + 1;
    if not nid = any (touched) then
      touched := touched || nid;
    end if;
    lvl := r ->> 'level';
    flt := public.iot_codes(r -> 'faults', public.iot_fault_codes());

    if lvl is distinct from coalesce(lat.level, 'ok') then
      insert into node_alert_events (node_id, measured_at, level, previous_level, reasons, cause, confidence,
                                     water_stress, heat_stress, anomaly, soil_moisture_pct, air_temp_c, faults)
      values (nid, t_meas, lvl, lat.level,
              public.iot_codes(r -> 'reasons', public.iot_reason_codes()),
              case when r ->> 'cause' in ('water', 'heat', 'sensor') then r ->> 'cause' end,
              public.iot_num(r, 'confidence'),
              round(public.iot_num(r, 'water_stress')), round(public.iot_num(r, 'heat_stress')),
              public.iot_num(r, 'anomaly'), public.iot_num(r, 'soil_moisture_pct'),
              public.iot_num(r, 'air_temp_c'), flt);
      n_events := n_events + 1;
    end if;

    if cardinality(flt) > 0 then
      insert into node_fault_days (node_id, day, code, count, first_at, last_at)
      select nid, (t_meas at time zone 'Africa/Tunis')::date, c, 1, t_meas, t_meas from unnest(flt) as c
      on conflict (node_id, day, code) do update
        set count = node_fault_days.count + 1,
            last_at = greatest(node_fault_days.last_at, excluded.last_at);
    end if;

    hist_at := lat.history_at;
    if hist_at is null or t_meas >= hist_at + make_interval(mins => gw.history_minutes) * 0.9 then
      insert into node_readings (node_id, measured_at, soil_moisture_pct, soil_temp_c, air_temp_c,
                                 humidity_pct, light_par, vpd_kpa, battery_pct, rssi_dbm, water_stress,
                                 heat_stress, anomaly, drying_rate_pct_h, hours_above_35c, packets_lost,
                                 level, faults, light_adc, piezo_rms, piezo_events_h)
      values (nid, t_meas, public.iot_num(r, 'soil_moisture_pct'), public.iot_num(r, 'soil_temp_c'),
              public.iot_num(r, 'air_temp_c'), public.iot_num(r, 'humidity_pct'),
              public.iot_num(r, 'light_par'), public.iot_num(r, 'vpd_kpa'),
              public.iot_num(r, 'battery_pct'), round(public.iot_num(r, 'rssi_dbm')),
              round(public.iot_num(r, 'water_stress')), round(public.iot_num(r, 'heat_stress')),
              public.iot_num(r, 'anomaly'), public.iot_num(r, 'drying_rate_pct_h'),
              public.iot_num(r, 'hours_above_35c'), round(public.iot_num(r, 'packets_lost')),
              lvl, flt, round(public.iot_num(r, 'light_adc')), public.iot_num(r, 'piezo_rms'),
              public.iot_num(r, 'piezo_events_h'))
      on conflict (node_id, measured_at) do nothing;
      hist_at := t_meas;
      stored := stored + 1;
    end if;

    insert into node_latest (node_id, gateway_id, measured_at, received_at, soil_moisture_pct, soil_temp_c,
                             air_temp_c, humidity_pct, light_par, vpd_kpa, battery_pct, rssi_dbm,
                             water_stress, heat_stress, anomaly, drying_rate_pct_h, hours_above_35c,
                             packets_lost, level, faults, reasons, cause, confidence, seq, firmware,
                             model, history_at, light_adc, piezo_rms, piezo_events_h)
    values (nid, gw.id, t_meas, now(), public.iot_num(r, 'soil_moisture_pct'), public.iot_num(r, 'soil_temp_c'),
            public.iot_num(r, 'air_temp_c'), public.iot_num(r, 'humidity_pct'),
            public.iot_num(r, 'light_par'), public.iot_num(r, 'vpd_kpa'),
            public.iot_num(r, 'battery_pct'), round(public.iot_num(r, 'rssi_dbm')),
            round(public.iot_num(r, 'water_stress')), round(public.iot_num(r, 'heat_stress')),
            public.iot_num(r, 'anomaly'), public.iot_num(r, 'drying_rate_pct_h'),
            public.iot_num(r, 'hours_above_35c'), round(public.iot_num(r, 'packets_lost')),
            lvl, flt, public.iot_codes(r -> 'reasons', public.iot_reason_codes()),
            case when r ->> 'cause' in ('water', 'heat', 'sensor') then r ->> 'cause' end,
            public.iot_num(r, 'confidence'), round(public.iot_num(r, 'seq')),
            case when r ->> 'firmware' ~ '^[0-9A-Za-z._-]{1,20}$' then r ->> 'firmware' end,
            case when r ->> 'model' ~ '^[0-9A-Za-z._-]{1,20}$' then r ->> 'model' end,
            hist_at, round(public.iot_num(r, 'light_adc')), public.iot_num(r, 'piezo_rms'),
            public.iot_num(r, 'piezo_events_h'))
    on conflict (node_id) do update set
      gateway_id = excluded.gateway_id, measured_at = excluded.measured_at,
      received_at = excluded.received_at, soil_moisture_pct = excluded.soil_moisture_pct,
      soil_temp_c = excluded.soil_temp_c, air_temp_c = excluded.air_temp_c,
      humidity_pct = excluded.humidity_pct, light_par = excluded.light_par, vpd_kpa = excluded.vpd_kpa,
      battery_pct = excluded.battery_pct, rssi_dbm = excluded.rssi_dbm,
      water_stress = excluded.water_stress, heat_stress = excluded.heat_stress,
      anomaly = excluded.anomaly, drying_rate_pct_h = excluded.drying_rate_pct_h,
      hours_above_35c = excluded.hours_above_35c, packets_lost = excluded.packets_lost,
      level = excluded.level, faults = excluded.faults, reasons = excluded.reasons,
      cause = excluded.cause, confidence = excluded.confidence, seq = excluded.seq,
      firmware = excluded.firmware, model = excluded.model, history_at = excluded.history_at,
      light_adc = excluded.light_adc, piezo_rms = excluded.piezo_rms, piezo_events_h = excluded.piezo_events_h;
  end loop;

  update nodes n set
    status = 'online',
    last_seen = now(),
    battery = coalesce(greatest(0, least(100, round(l.battery_pct)))::integer, n.battery)
  from node_latest l
  where l.node_id = n.id and n.id = any (touched);
  update nodes n set last_refused_at = now(), last_refused_reason = refused_box ->> n.id::text
  where refused_box ? n.id::text;
  delete from node_readings x using node_latest l
  where x.node_id = any (touched) and l.node_id = x.node_id
    and x.measured_at < l.measured_at - make_interval(days => keep_days);
  delete from node_alert_events x using node_latest l
  where x.node_id = any (touched) and l.node_id = x.node_id
    and x.measured_at < l.measured_at - make_interval(days => keep_days);
  delete from node_fault_days x using node_latest l
  where x.node_id = any (touched) and l.node_id = x.node_id
    and x.day < (l.measured_at at time zone 'Africa/Tunis')::date - keep_days;

  result := jsonb_build_object('accepted', accepted, 'history', stored, 'events', n_events,
                               'old', n_old, 'restarts', restarts,
                               'refused', refused, 'refused_devices', refused_dev);
  update gateways set last_seen_at = now(), last_result = result where id = gw.id;
  return result;
end;
$$;


-- ---------- 4) The predictions ----------
create or replace function public.ml_states(p_model text) returns text[]
language sql immutable as $$
  select case p_model
    when 'stress' then array['none', 'water_deficit', 'waterlogging', 'heat', 'frost', 'rootzone']
    when 'frost'  then array['frost_risk', 'no_frost']
  end;
$$;

-- The factors shown to farmers (each model feature belongs to one of them).
create or replace function public.ml_factor_codes() returns text[]
language sql immutable as $$
  select array['soil_water', 'soil_drying', 'soil_too_wet', 'watering', 'tree_water_need', 'air_heat',
               'night_cold', 'evening_temp', 'cooling_fast', 'night_low_expected', 'dew_point', 'air_humidity',
               'air_dryness', 'clear_sky', 'sunlight', 'soil_temp', 'tree_sounds', 'season_stage', 'zone_place',
               'soil_type', 'irrigation_type', 'ground_cover', 'other_zones', 'data_quality'];
$$;

-- A problem the farmer is told about (a notification).
create or replace function public.ml_is_problem(p_model text, p_state text) returns boolean
language sql immutable as $$
  select (p_model = 'frost' and p_state = 'frost_risk')
      or (p_model = 'stress' and p_state in ('water_deficit', 'waterlogging', 'heat', 'frost', 'rootzone'));
$$;

create table if not exists ml_latest (
  node_id             uuid not null references nodes(id) on delete cascade,
  model               text not null check (model in ('frost', 'stress')),
  zone_id             uuid references zones(id) on delete cascade,
  orchard_id          uuid references orchards(id) on delete cascade,
  farmer_id           uuid references profiles(id) on delete cascade,
  measured_at         timestamptz not null,
  predicted_at        timestamptz not null default now(),
  status              text not null check (status in ('ok', 'not_enough_data', 'sensor_problem')),
  state               text,
  confidence          real check (confidence is null or confidence between 0 and 1),
  certainty           text check (certainty is null or certainty in ('likely', 'unsure')),
  probabilities       jsonb,
  threshold           real,
  factors             jsonb not null default '[]',
  readings            jsonb not null default '{}',
  explanation_ar      text,
  explanation_fr      text,
  action_ar           text,
  action_fr           text,
  explanation_source  text,
  explanation_key     text,
  model_version       text,
  state_since         timestamptz,
  primary key (node_id, model),
  check (state is null or state = any (public.ml_states(model)))
);
comment on table ml_latest is 'The last prediction of each sensor box and model (written only by the ML worker).';
comment on column ml_latest.factors is
  'The main reasons (SHAP): [{"code", "level": "low"|"high", "share" 0..1, "feature", "value", "shap"}]. The app shows only the code.';

create table if not exists ml_history (
  id                  bigint generated always as identity primary key,
  node_id             uuid not null references nodes(id) on delete cascade,
  model               text not null check (model in ('frost', 'stress')),
  measured_at         timestamptz not null,
  created_at          timestamptz not null default now(),
  status              text not null check (status in ('ok', 'not_enough_data', 'sensor_problem')),
  state               text,
  confidence          real,
  certainty           text,
  probabilities       jsonb,
  factors             jsonb not null default '[]',
  explanation_ar      text,
  explanation_fr      text,
  action_ar           text,
  action_fr           text,
  explanation_source  text,
  model_version       text,
  changed             boolean not null default false,
  unique (node_id, model, measured_at)
);
create index if not exists ml_history_node_time_idx on ml_history (node_id, model, measured_at desc);
comment on table ml_history is 'Prediction history: a point when the state changes, else one per hour of measured time.';

create table if not exists ml_notifications (
  id           uuid primary key default gen_random_uuid(),
  farmer_id    uuid not null references profiles(id) on delete cascade,
  node_id      uuid not null references nodes(id) on delete cascade,
  zone_id      uuid references zones(id) on delete cascade,
  model        text not null check (model in ('frost', 'stress')),
  state        text not null,
  severity     text not null check (severity in ('warning', 'danger')),
  confidence   real,
  certainty    text check (certainty is null or certainty in ('likely', 'unsure')),
  measured_at  timestamptz not null,
  created_at   timestamptz not null default now(),
  read_at      timestamptz,
  resolved_at  timestamptz,
  check (public.ml_is_problem(model, state))
);
create index if not exists ml_notifications_farmer_idx on ml_notifications (farmer_id, created_at desc);
-- One open notification per box and model: never the same problem twice.
create unique index if not exists ml_notifications_one_open on ml_notifications (node_id, model)
  where resolved_at is null;
comment on table ml_notifications is
  'In-app notifications of the predictions: one per problem (box + model), resolved when the problem ends.';


-- ---------- 5) The app: mark a notification read ----------
create or replace function public.ml_notification_mark(p_id uuid, p_action text default 'read')
returns integer
language plpgsql security definer set search_path = public as $$
declare
  n integer;
begin
  if auth.uid() is null then
    raise exception 'Login required' using errcode = '42501';
  end if;
  if p_action = 'read' then
    update ml_notifications set read_at = coalesce(read_at, now())
    where id = p_id and farmer_id = auth.uid();
  elsif p_action = 'read_all' then
    update ml_notifications set read_at = coalesce(read_at, now())
    where farmer_id = auth.uid() and read_at is null;
  else
    raise exception 'Unknown action' using errcode = '22023';
  end if;
  get diagnostics n = row_count;
  return n;
end;
$$;


-- ---------- 6) The ML worker (its key, its 3 functions) ----------
create table if not exists ml_workers (
  code          text primary key check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  key_hash      text unique check (key_hash is null or key_hash ~ '^[0-9a-f]{64}$'),
  enabled       boolean not null default true,
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz,
  last_result   jsonb
);
comment on table ml_workers is 'The ML worker(s) (Python). Only the sha256 of the key is kept.';

-- A NEW key for a worker (made if needed). Shown once: paste it in
-- dashboard/backend/.env (ML_WORKER_KEY=). The old key stops at once.
create or replace function public.ml_worker_new_key(p_code text)
returns text
language plpgsql security definer set search_path = public as $$
declare
  wcode   text := upper(btrim(coalesce(p_code, '')));
  new_key text := 'lml_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  if auth.uid() is not null and not public.admin_sees_all() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if wcode !~ '^[A-Z0-9][A-Z0-9_-]{1,31}$' then
    raise exception 'Worker code: 2 to 32 capital letters, digits, - or _' using errcode = '22023';
  end if;
  insert into ml_workers (code, key_hash) values (wcode, encode(sha256(convert_to(new_key, 'UTF8')), 'hex'))
  on conflict (code) do update set key_hash = excluded.key_hash;
  return new_key;
end;
$$;

-- The worker of a key (or an error PT401).
create or replace function public.ml_worker_check(p_key text) returns ml_workers
language plpgsql security definer set search_path = public as $$
declare
  w ml_workers;
begin
  if p_key is null or p_key !~ '^lml_[0-9a-f]{64}$' then
    raise exception 'Unknown worker' using errcode = 'PT401';
  end if;
  select * into w from ml_workers
  where key_hash = encode(sha256(convert_to(p_key, 'UTF8')), 'hex') and enabled;
  if w.code is null then
    raise exception 'Unknown worker' using errcode = 'PT401';
  end if;
  update ml_workers set last_seen_at = now() where code = w.code;
  return w;
end;
$$;

-- The boxes to predict now: installed, of a farmer with a paid pack, with a
-- reading newer than their last prediction. With their context and the last
-- prediction (to keep the Groq text when nothing changed).
create or replace function public.ml_worker_jobs(p_key text, p_limit integer default 50)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s     app_settings;
  jobs  jsonb;
begin
  perform public.ml_worker_check(p_key);
  select * into s from app_settings where id;
  select coalesce(jsonb_agg(j order by j ->> 'measured_at'), '[]') into jobs from (
    select jsonb_build_object(
      'node_id', n.id, 'device_code', n.hardware_id, 'zone_id', z.id, 'zone_letter', z.letter,
      'zone_name', z.name, 'orchard_id', o.id, 'farmer_id', o.farmer_id,
      'measured_at', l.measured_at, 'level', l.level, 'faults', to_jsonb(l.faults),
      'offline_after_minutes', coalesce(g.offline_after_minutes, 35), 'time_mode', coalesce(g.time_mode, 'real'),
      'latest', jsonb_build_object('soil_moisture_pct', l.soil_moisture_pct, 'soil_temp_c', l.soil_temp_c,
        'air_temp_c', l.air_temp_c, 'humidity_pct', l.humidity_pct, 'light_adc', l.light_adc,
        'piezo_rms', l.piezo_rms, 'piezo_events_h', l.piezo_events_h, 'battery_pct', l.battery_pct),
      'context', public.ml_zone_context(z.id),
      'previous', coalesce((select jsonb_object_agg(m.model, jsonb_build_object(
          'measured_at', m.measured_at, 'status', m.status, 'state', m.state, 'certainty', m.certainty,
          'explanation_key', m.explanation_key, 'explanation_ar', m.explanation_ar,
          'explanation_fr', m.explanation_fr, 'action_ar', m.action_ar, 'action_fr', m.action_fr,
          'explanation_source', m.explanation_source))
        from ml_latest m where m.node_id = n.id), '{}')) as j
    from nodes n
    join zones z on z.id = n.zone_id and z.archived_at is null
    join orchards o on o.id = z.orchard_id
    join node_latest l on l.node_id = n.id
    left join lateral (select gg.* from gateways gg where gg.orchard_id = o.id
                       order by gg.last_seen_at desc nulls last limit 1) g on true
    where n.installed_at is not null
      and public.has_paid_pack(o.farmer_id)
      and (select count(*) from ml_latest m where m.node_id = n.id and m.measured_at >= l.measured_at) < 2
    order by l.measured_at
    limit greatest(1, least(coalesce(p_limit, 50), 500))
  ) x;
  return jsonb_build_object(
    'settings', jsonb_build_object('ml_enabled', s.ml_enabled, 'ml_notify_enabled', s.ml_notify_enabled,
      'ml_explain_enabled', s.ml_explain_enabled, 'ml_groq_model', s.ml_groq_model,
      'ml_likely_min', s.ml_likely_min, 'iot_history_days', s.iot_history_days),
    'jobs', case when s.ml_enabled then jobs else '[]'::jsonb end);
end;
$$;

-- The readings of every box of an orchard since a time (the history points
-- of node_readings, then the latest reading), for the features.
-- Each point: [epoch seconds, soil %, soil °C, air °C, air %, light ADC,
--              piezo RMS, piezo events/h, number of faults].
create or replace function public.ml_worker_history(p_key text, p_orchard uuid, p_since timestamptz)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  since timestamptz;
begin
  perform public.ml_worker_check(p_key);
  since := greatest(coalesce(p_since, now() - interval '20 days'),
                    coalesce((select max(l.measured_at) from node_latest l join nodes n on n.id = l.node_id
                              join zones z on z.id = n.zone_id where z.orchard_id = p_orchard), now())
                    - interval '21 days');
  return jsonb_build_object('orchard_id', p_orchard, 'nodes', coalesce((
    select jsonb_object_agg(x.node_id, x.points) from (
      select n.id as node_id, (
        select coalesce(jsonb_agg(jsonb_build_array(round(extract(epoch from p.measured_at)), p.soil_moisture_pct,
                 p.soil_temp_c, p.air_temp_c, p.humidity_pct, p.light_adc, p.piezo_rms, p.piezo_events_h,
                 cardinality(p.faults)) order by p.measured_at), '[]')
        from (
          select r.measured_at, r.soil_moisture_pct, r.soil_temp_c, r.air_temp_c, r.humidity_pct, r.light_adc,
                 r.piezo_rms, r.piezo_events_h, r.faults
          from node_readings r where r.node_id = n.id and r.measured_at >= since
          union
          select l.measured_at, l.soil_moisture_pct, l.soil_temp_c, l.air_temp_c, l.humidity_pct, l.light_adc,
                 l.piezo_rms, l.piezo_events_h, l.faults
          from node_latest l where l.node_id = n.id and l.measured_at >= since
        ) p) as points
      from nodes n join zones z on z.id = n.zone_id
      where z.orchard_id = p_orchard and z.archived_at is null and n.installed_at is not null
    ) x), '{}'));
end;
$$;

-- Text of a model, kept only if it is clean (else null: the app writes its own).
create or replace function public.ml_clean_text(p text, p_max integer) returns text
language sql immutable as $$
  select case when p is not null and length(btrim(p)) between 1 and p_max
               and p !~ '[<>\x01-\x08\x0b\x0c\x0e-\x1f\u200e\u200f\u202a-\u202e\u2066-\u2069]'
              then btrim(p) end;
$$;

-- The worker saves its predictions: [{node_id, model, measured_at, status,
-- state, confidence, certainty, probabilities, threshold, factors, readings,
-- explanation {ar: {text, action}, fr: {...}} | null, explanation_source,
-- explanation_key, model_version}]. Returns {saved, history, notified,
-- resolved, refused}.
create or replace function public.ml_worker_save(p_key text, p_batch jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  w          ml_workers;
  s          app_settings;
  p          jsonb;
  nid        uuid;
  z          zones;
  o          orchards;
  mdl        text;
  st         text;
  stt        text;
  t_meas     timestamptz;
  prev       ml_latest;
  last_hist  timestamptz;
  changed    boolean;
  conf       real;
  cert       text;
  facts      jsonb;
  hid        bigint;
  open_n     ml_notifications;
  saved      integer := 0;
  n_hist     integer := 0;
  notified   integer := 0;
  resolved   integer := 0;
  refused    integer := 0;
  keep_days  integer;
  result     jsonb;
begin
  w := public.ml_worker_check(p_key);
  select * into s from app_settings where id;
  keep_days := coalesce(s.iot_history_days, 30);
  if jsonb_typeof(p_batch) is distinct from 'object' or jsonb_typeof(p_batch -> 'predictions') is distinct from 'array'
     or jsonb_array_length(p_batch -> 'predictions') > 500 then
    raise exception 'Bad batch: {"predictions": [...]} (500 at most) expected' using errcode = '22023';
  end if;

  for p in select value from jsonb_array_elements(p_batch -> 'predictions') loop
    nid := null; z := null; o := null;
    begin
      nid := (p ->> 'node_id')::uuid;
    exception when others then
      nid := null;
    end;
    mdl := p ->> 'model';
    st := p ->> 'status';
    stt := nullif(p ->> 'state', '');
    t_meas := public.iot_time(p ->> 'measured_at');
    if nid is not null then
      select zz.* into z from nodes n join zones zz on zz.id = n.zone_id where n.id = nid;
      select * into o from orchards where id = z.orchard_id;
    end if;
    conf := case when jsonb_typeof(p -> 'confidence') = 'number' then (p ->> 'confidence')::real end;
    cert := p ->> 'certainty';
    if z.id is null or mdl not in ('frost', 'stress') or st not in ('ok', 'not_enough_data', 'sensor_problem')
       or t_meas is null or (st = 'ok' and (stt is null or not stt = any (public.ml_states(mdl))))
       or (st <> 'ok' and stt is not null)
       or (conf is not null and conf not between 0 and 1)
       or (cert is not null and cert not in ('likely', 'unsure')) then
      refused := refused + 1;
      continue;
    end if;
    -- factors: codes of the list only, 6 at most
    select coalesce(jsonb_agg(jsonb_build_object(
             'code', f ->> 'code',
             'level', case when f ->> 'level' in ('low', 'high') then f ->> 'level' end,
             'share', case when jsonb_typeof(f -> 'share') = 'number' then round((f ->> 'share')::numeric, 3) end,
             'feature', case when f ->> 'feature' ~ '^[a-z0-9_]{1,60}$' then f ->> 'feature' end,
             'value', case when jsonb_typeof(f -> 'value') = 'number' then round((f ->> 'value')::numeric, 4) end,
             'shap', case when jsonb_typeof(f -> 'shap') = 'number' then round((f ->> 'shap')::numeric, 4) end)
             order by i), '[]')
      into facts
    from jsonb_array_elements(case when jsonb_typeof(p -> 'factors') = 'array' then p -> 'factors' else '[]' end)
         with ordinality as e(f, i)
    where i <= 6 and f ->> 'code' = any (public.ml_factor_codes());

    select * into prev from ml_latest where node_id = nid and model = mdl;
    if prev.node_id is not null and t_meas < prev.measured_at then
      refused := refused + 1;
      continue;
    end if;
    changed := prev.node_id is null or prev.status is distinct from st or prev.state is distinct from stt;

    insert into ml_latest as m (node_id, model, zone_id, orchard_id, farmer_id, measured_at, predicted_at, status,
                                state, confidence, certainty, probabilities, threshold, factors, readings,
                                explanation_ar, explanation_fr, action_ar, action_fr, explanation_source,
                                explanation_key, model_version, state_since)
    values (nid, mdl, z.id, o.id, o.farmer_id, t_meas, now(), st, stt, conf, cert,
            case when jsonb_typeof(p -> 'probabilities') = 'object' then p -> 'probabilities' end,
            case when jsonb_typeof(p -> 'threshold') = 'number' then (p ->> 'threshold')::real end,
            facts,
            case when jsonb_typeof(p -> 'readings') = 'object' then p -> 'readings' else '{}' end,
            public.ml_clean_text(p #>> '{explanation,ar,text}', 600),
            public.ml_clean_text(p #>> '{explanation,fr,text}', 600),
            public.ml_clean_text(p #>> '{explanation,ar,action}', 300),
            public.ml_clean_text(p #>> '{explanation,fr,action}', 300),
            case when p ->> 'explanation_source' ~ '^(template|groq:[a-z0-9._/-]{1,80})$' then p ->> 'explanation_source' end,
            left(p ->> 'explanation_key', 200),
            case when p ->> 'model_version' ~ '^[A-Za-z0-9._:-]{1,60}$' then p ->> 'model_version' end,
            t_meas)
    on conflict (node_id, model) do update set
      zone_id = excluded.zone_id, orchard_id = excluded.orchard_id, farmer_id = excluded.farmer_id,
      measured_at = excluded.measured_at, predicted_at = excluded.predicted_at, status = excluded.status,
      state = excluded.state, confidence = excluded.confidence, certainty = excluded.certainty,
      probabilities = excluded.probabilities, threshold = excluded.threshold, factors = excluded.factors,
      readings = excluded.readings, explanation_ar = excluded.explanation_ar,
      explanation_fr = excluded.explanation_fr, action_ar = excluded.action_ar, action_fr = excluded.action_fr,
      explanation_source = excluded.explanation_source, explanation_key = excluded.explanation_key,
      model_version = excluded.model_version,
      state_since = case when m.status is distinct from excluded.status or m.state is distinct from excluded.state
                         then excluded.measured_at else m.state_since end;
    saved := saved + 1;

    -- history: when the state changes, else once per hour of measured time
    select max(h.measured_at) into last_hist from ml_history h where h.node_id = nid and h.model = mdl;
    hid := null;
    if changed or last_hist is null or t_meas >= last_hist + interval '54 minutes' then
      insert into ml_history (node_id, model, measured_at, status, state, confidence, certainty, probabilities,
                              factors, explanation_ar, explanation_fr, action_ar, action_fr, explanation_source,
                              model_version, changed)
      select m.node_id, m.model, m.measured_at, m.status, m.state, m.confidence, m.certainty, m.probabilities,
             m.factors, m.explanation_ar, m.explanation_fr, m.action_ar, m.action_fr, m.explanation_source,
             m.model_version, changed
      from ml_latest m where m.node_id = nid and m.model = mdl
      on conflict (node_id, model, measured_at) do nothing
      returning id into hid;
      if hid is not null then n_hist := n_hist + 1; end if;
    end if;

    -- in-app notifications (only for real states, never for "no data" / sensor)
    if st = 'ok' then
      select * into open_n from ml_notifications where node_id = nid and model = mdl and resolved_at is null;
      if public.ml_is_problem(mdl, stt) then
        if open_n.id is not null and open_n.state = stt then
          null;                                                 -- the same problem: no repeat
        else
          if open_n.id is not null then                        -- another problem: the old one ends
            update ml_notifications set resolved_at = now() where id = open_n.id;
            resolved := resolved + 1;
          end if;
          -- The same problem ended less than 12 h (measured) ago: it comes back
          -- (no new notification), else a new one.
          update ml_notifications set resolved_at = null
          where id = (select x.id from ml_notifications x
                      where x.node_id = nid and x.model = mdl and x.state = stt and x.resolved_at is not null
                        and x.measured_at > t_meas - interval '12 hours'
                      order by x.created_at desc limit 1);
          if not found and s.ml_notify_enabled then
            insert into ml_notifications (farmer_id, node_id, zone_id, model, state, severity, confidence,
                                          certainty, measured_at)
            values (o.farmer_id, nid, z.id, mdl, stt,
                    case when stt in ('frost_risk', 'frost') then 'danger' else 'warning' end,
                    conf, cert, t_meas);
            notified := notified + 1;
          end if;
        end if;
      elsif open_n.id is not null then
        update ml_notifications set resolved_at = now() where id = open_n.id;
        resolved := resolved + 1;
      end if;
    end if;

    -- keep iot_history_days of measured time
    delete from ml_history h where h.node_id = nid and h.model = mdl
      and h.measured_at < t_meas - make_interval(days => keep_days);
  end loop;

  delete from ml_notifications where resolved_at is not null and created_at < now() - interval '30 days';
  result := jsonb_build_object('saved', saved, 'history', n_hist, 'notified', notified,
                               'resolved', resolved, 'refused', refused);
  update ml_workers set last_result = result where code = w.code;
  return result;
end;
$$;


-- ---------- 7) The state of every box: the new channels at the end ----------
create or replace view public.iot_node_status with (security_invoker = true) as
select
  n.id                  as node_id,
  n.zone_id,
  z.orchard_id,
  o.farmer_id,
  z.letter              as zone_letter,
  z.name                as zone_name,
  z.color               as zone_color,
  z.zone_type,
  z.tree_count,
  z.cultivar,
  z.planted_year,
  n.hardware_id         as device_code,
  n.position_x,
  n.position_z,
  n.installed_at,
  n.installed_by,
  n.last_seen           as received_at,
  n.last_refused_at,
  n.last_refused_reason,
  g.id                  as gateway_id,
  g.code                as gateway_code,
  g.time_mode,
  l.measured_at,
  l.soil_moisture_pct,
  l.soil_temp_c,
  l.air_temp_c,
  l.humidity_pct,
  l.light_par,
  l.vpd_kpa,
  l.battery_pct,
  l.rssi_dbm,
  l.water_stress,
  l.heat_stress,
  l.anomaly,
  l.drying_rate_pct_h,
  l.hours_above_35c,
  l.level,
  l.reasons,
  l.cause,
  l.confidence,
  l.faults,
  l.packets_lost,
  l.firmware,
  case
    when n.installed_at is null then 'waiting'
    when l.node_id is null then 'installed'
    when n.last_seen is null
      or n.last_seen < now() - make_interval(mins => coalesce(g.offline_after_minutes, 35)) then 'offline'
    when cardinality(l.faults) > 0 or l.level = 'sensor' then 'sensor_problem'
    else 'online'
  end                   as status,
  l.light_adc,
  l.piezo_rms,
  l.piezo_events_h,
  coalesce(g.offline_after_minutes, 35) as offline_after_minutes
from nodes n
join zones z on z.id = n.zone_id and z.archived_at is null
join orchards o on o.id = z.orchard_id
left join node_latest l on l.node_id = n.id
left join lateral (
  select gg.* from gateways gg where gg.orchard_id = o.id
  order by gg.last_seen_at desc nulls last, gg.created_at limit 1
) g on true;


-- ---------- 8) The rules (RLS), the rights and Realtime ----------
alter table ml_latest        enable row level security;
alter table ml_history       enable row level security;
alter table ml_notifications enable row level security;
alter table ml_workers       enable row level security;

drop policy if exists "Farmers see the predictions of their boxes" on ml_latest;
create policy "Farmers see the predictions of their boxes" on ml_latest for select to authenticated
  using (public.owns_node(node_id) and public.has_plan('paid'));
drop policy if exists "Admins see all predictions" on ml_latest;
create policy "Admins see all predictions" on ml_latest for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and node_id = any ((select public.demo_node_ids())::uuid[])));

drop policy if exists "Farmers see the prediction history of their boxes" on ml_history;
create policy "Farmers see the prediction history of their boxes" on ml_history for select to authenticated
  using (public.owns_node(node_id) and public.has_plan('paid'));
drop policy if exists "Admins see all prediction history" on ml_history;
create policy "Admins see all prediction history" on ml_history for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and node_id = any ((select public.demo_node_ids())::uuid[])));

drop policy if exists "Farmers see their notifications" on ml_notifications;
create policy "Farmers see their notifications" on ml_notifications for select to authenticated
  using (farmer_id = (select auth.uid()) and public.has_plan('paid'));
drop policy if exists "Admins see all notifications" on ml_notifications;
create policy "Admins see all notifications" on ml_notifications for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and farmer_id = any ((select public.demo_person_ids())::uuid[])));

drop policy if exists "Admins see the ML workers" on ml_workers;
create policy "Admins see the ML workers" on ml_workers for select to authenticated
  using ((select public.admin_sees_all()));

-- Nobody writes them by hand (only the functions above).
revoke all on ml_latest, ml_history, ml_notifications, ml_workers from anon, authenticated;
grant select on ml_latest, ml_history, ml_notifications, ml_workers to authenticated;
grant all on ml_latest, ml_history, ml_notifications, ml_workers to service_role;

revoke all on function public.ml_governorate_defaults(text) from public, anon;
revoke all on function public.ml_soil_defaults(text)        from public, anon;
revoke all on function public.ml_zone_context(uuid)         from public, anon, authenticated;
revoke all on function public.ml_worker_new_key(text)       from public, anon;
revoke all on function public.ml_worker_check(text)         from public, anon, authenticated;
revoke all on function public.ml_notification_mark(uuid, text) from public, anon;
grant execute on function public.ml_governorate_defaults(text), public.ml_soil_defaults(text),
  public.ml_states(text), public.ml_factor_codes(), public.ml_is_problem(text, text),
  public.ml_clean_text(text, integer) to authenticated, service_role;
grant execute on function public.ml_zone_context(uuid), public.ml_worker_check(text) to service_role;
grant execute on function public.ml_worker_new_key(text), public.ml_notification_mark(uuid, text)
  to authenticated, service_role;
-- The 3 worker functions check the worker's key themselves (no key = PT401):
-- the worker calls them with the public (publishable) key of the project.
grant execute on function public.ml_worker_jobs(text, integer), public.ml_worker_history(text, uuid, timestamptz),
  public.ml_worker_save(text, jsonb) to anon, authenticated, service_role;

-- The admins read the context used for a zone (dashboard).
create or replace function public.admin_zone_context(p_zone uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.admin_sees_all() or (public.is_demo_admin()
          and exists (select 1 from zones z where z.id = p_zone and z.orchard_id = any (public.demo_orchard_ids())))) then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  return public.ml_zone_context(p_zone);
end;
$$;
revoke all on function public.admin_zone_context(uuid) from public, anon;
grant execute on function public.admin_zone_context(uuid) to authenticated, service_role;

-- Supabase Realtime: these tables reach the app as soon as they change
-- (each person receives only the rows the rules above let him read).
do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['node_latest', 'ml_latest', 'ml_notifications'] loop
      if not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;


-- ---------- 9) Last check: you should see  true | qwen/qwen3.8-27b | 3 | true | false | false | 4 ----------
--   ml_on            true
--   groq_model       the Groq model of the explanations
--   realtime_tables  3   (node_latest, ml_latest, ml_notifications)
--   rules_on         true
--   visitors_read    false (a visitor reads no prediction)
--   app_can_write    false (the app cannot write a prediction itself)
--   demo_zones_ready 4   (the 4 zones of 22 777 001 have their soil; 0 if that account is not there)
select
  (select ml_enabled from app_settings where id)                                              as ml_on,
  (select ml_groq_model from app_settings where id)                                           as groq_model,
  (select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public'
     and tablename in ('node_latest', 'ml_latest', 'ml_notifications'))                       as realtime_tables,
  (select bool_and(relrowsecurity) from pg_class
   where relname in ('ml_latest', 'ml_history', 'ml_notifications', 'ml_workers')
     and relnamespace = 'public'::regnamespace)                                               as rules_on,
  has_table_privilege('anon', 'public.ml_latest', 'select')                                   as visitors_read,
  has_table_privilege('authenticated', 'public.ml_latest', 'insert')                          as app_can_write,
  (select count(*) from zones z join orchards o on o.id = z.orchard_id join profiles p on p.id = o.farmer_id
   where p.phone = '+21622777001' and o.is_demo and z.archived_at is null and z.soil_type is not null) as demo_zones_ready;
