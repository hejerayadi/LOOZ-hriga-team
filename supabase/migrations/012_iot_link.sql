-- =========================================================
-- LOOZ — Migration 012: the IoT link (gateway on the farm -> Supabase)
--
-- What it does:
--   1. GATEWAYS: the computer on the farm (Node-RED) that collects the
--      readings of the sensor boxes (nodes). Each gateway belongs to ONE
--      orchard and has a secret KEY. Only a hash (sha256) of the key is
--      kept here; the key itself is shown once (iot_gateway_new_key) and
--      then lives only in the gateway's .env file.
--   2. The Edge Function "iot-ingest" receives a batch of readings from a
--      gateway (about once a minute) and calls iot_ingest() below. A reading
--      is ACCEPTED only if:
--        - its box (nodes.hardware_id = the device code, e.g. NODE-02) is in
--          the gateway's own orchard and its zone is not archived,
--        - an admin ACCEPTED the installation of that box (nodes.installed_at),
--        - the farmer has an active paid pack.
--      Everything else is refused and counted (the gateway sees why).
--   3. Where the readings go:
--        node_latest        the last reading of each box (1 row per box)
--        node_readings      the history for the charts: 1 point per box every
--                           gateways.history_minutes of MEASURED time
--        node_alert_events  each time the level of a box changes (alert log)
--        node_fault_days    sensor problems, counted per box, day and code
--      Older than app_settings.iot_history_days (30) of measured time:
--      deleted by iot_ingest itself (no extra job needed).
--   4. CODES, never sentences: levels (ok, info, watch, warning, critical,
--      sensor), reasons and fault codes. Each app shows them in its language.
--   5. TIME: measured_at = when the box measured (in DEMO mode: the
--      simulated clock of Node-RED); nodes.last_seen = when Supabase
--      received it (real time). "Last reading X min ago" uses last_seen.
--      A demo gateway whose simulated clock goes back (Node-RED restarted
--      without its memory) starts the history of its boxes again.
--   6. Admins: iot_accept_node() / iot_unaccept_node() (the "Accepter" button
--      of the dashboard), iot_gateway_new_key(); the view iot_node_status
--      gives the state of every box (waiting, installed, online, offline,
--      sensor_problem).
--   7. Security: only the Edge Function (service_role) can call iot_ingest.
--      Admins read everything; a farmer reads only his own boxes, with the
--      paid pack. Nobody writes the readings by hand.
--   8. Last check.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 011. Safe to run again (no begin/commit, each
-- statement can be run again).
-- =========================================================


-- ---------- 1) Settings (admin) ----------
alter table app_settings add column if not exists iot_ingest_enabled boolean not null default true;
alter table app_settings add column if not exists iot_history_days   integer not null default 30;
alter table app_settings drop constraint if exists app_settings_iot_history_days_check;
alter table app_settings add constraint app_settings_iot_history_days_check
  check (iot_history_days between 1 and 3650);
comment on column app_settings.iot_ingest_enabled is
  'false = every gateway is refused (the readings are not saved). Emergency switch.';
comment on column app_settings.iot_history_days is
  'Days of MEASURED time kept per box (history, alert log, sensor problems).';


-- ---------- 2) The codes (one list each, used by the checks and by iot_ingest) ----------
create or replace function public.iot_levels() returns text[]
language sql immutable as $$
  select array['ok', 'info', 'watch', 'warning', 'critical', 'sensor'];
$$;

-- How serious a level is (sensor problem = like info).
create or replace function public.iot_level_rank(p text) returns integer
language sql immutable as $$
  select case p when 'ok' then 0 when 'info' then 1 when 'sensor' then 1 when 'watch' then 2
                when 'warning' then 3 when 'critical' then 4 end;
$$;

create or replace function public.iot_reason_codes() returns text[]
language sql immutable as $$
  select array['water_stress', 'heat_stress', 'unusual_drying', 'wilting_point', 'sensor_fault', 'other'];
$$;

create or replace function public.iot_fault_codes() returns text[]
language sql immutable as $$
  select array['checksum_invalid', 'soil_probe_disconnected', 'soil_probe_stuck', 'packets_lost',
               'duplicate_seq', 'battery_low', 'signal_weak',
               'soil_moisture_out_of_range', 'soil_temp_out_of_range', 'air_temp_out_of_range',
               'humidity_out_of_range', 'light_out_of_range', 'battery_out_of_range',
               'soil_moisture_missing', 'soil_temp_missing', 'air_temp_missing',
               'humidity_missing', 'light_missing', 'battery_missing', 'other'];
$$;

-- A JSON list of codes -> sorted, each once, 20 at most; unknown -> 'other'.
create or replace function public.iot_codes(p jsonb, allowed text[]) returns text[]
language sql immutable as $$
  select coalesce(array_agg(distinct x.c order by x.c), '{}')
  from (
    select case when e.v = any (allowed) then e.v else 'other' end as c
    from jsonb_array_elements_text(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end)
         with ordinality as e(v, i)
    where e.i <= 20
  ) x;
$$;

-- '2026-06-15T05:00:00Z' -> a time. The zone (Z or +01:00) is required.
-- Anything else -> null (never an error).
create or replace function public.iot_time(t text) returns timestamptz
language plpgsql stable as $$
begin
  if t is null
     or t !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]{1,6})?)?(Z|[+-][0-9]{2}(:?[0-9]{2})?)$' then
    return null;
  end if;
  return t::timestamptz;
exception when others then
  return null;
end;
$$;

-- What is wrong with one reading (null = fine): the level is required, the
-- numbers are optional but must be numbers inside wide physical limits.
-- (A faulty probe reading -1 or 101 % is KEPT, with its fault code.)
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
      ('seq', 0, 2147483647)) as t(k, lo, hi)
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

-- A number of a reading (null if missing; call iot_reading_problem first).
create or replace function public.iot_num(r jsonb, k text) returns double precision
language sql immutable as $$
  select case when jsonb_typeof(r -> k) = 'number' then (r ->> k)::double precision end;
$$;


-- ---------- 3) Zones: cultivar and planting year (optional) ----------
alter table zones add column if not exists cultivar     text;
alter table zones add column if not exists planted_year smallint;
alter table zones drop constraint if exists zones_cultivar_check;
alter table zones add constraint zones_cultivar_check
  check (cultivar is null or public.community_text_ok(cultivar, 40));
alter table zones drop constraint if exists zones_planted_year_check;
alter table zones add constraint zones_planted_year_check
  check (planted_year is null or planted_year between 1950 and 2100);
comment on column zones.cultivar is 'Almond variety of the zone (e.g. Nonpareil). Optional.';
comment on column zones.planted_year is 'Year the trees of the zone were planted (age = this year - planted_year).';


-- ---------- 4) Nodes (sensor boxes): device code, who accepted, refusals ----------
comment on column nodes.hardware_id is
  'DEVICE CODE of the box (printed on it, sent by the gateway), e.g. NODE-02. Unique.';
alter table nodes drop constraint if exists nodes_hardware_id_format;
alter table nodes add constraint nodes_hardware_id_format
  check (hardware_id is null or hardware_id ~ '^[A-Z0-9][A-Z0-9_-]{1,39}$') not valid;

-- One box per device code (created only if no code is used twice already).
do $$
begin
  if not exists (select 1 from nodes where hardware_id is not null
                 group by hardware_id having count(*) > 1) then
    create unique index if not exists nodes_hardware_id_unique on nodes (hardware_id)
      where hardware_id is not null;
  else
    raise notice 'Some device codes (nodes.hardware_id) are used twice: the unique rule is not added.';
  end if;
end $$;

alter table nodes add column if not exists installed_by        uuid references profiles(id) on delete set null;
alter table nodes add column if not exists last_refused_at     timestamptz;
alter table nodes add column if not exists last_refused_reason text;
alter table nodes drop constraint if exists nodes_last_refused_reason_check;
alter table nodes add constraint nodes_last_refused_reason_check
  check (last_refused_reason is null or last_refused_reason in
         ('not_installed', 'no_paid_pack', 'zone_archived', 'bad_time', 'bad_values'));
comment on column nodes.installed_at is
  'Set when an admin ACCEPTS the installation of the box (empty = waiting). Readings are refused before.';
comment on column nodes.last_seen is 'When Supabase last RECEIVED a reading of this box (real time).';
comment on column nodes.last_refused_at is 'Last time a reading of this box was refused (see last_refused_reason).';


-- ---------- 5) GATEWAYS ----------
create table if not exists gateways (
  id                    uuid primary key default gen_random_uuid(),
  code                  text not null unique check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  orchard_id            uuid not null references orchards(id) on delete cascade,
  key_hash              text unique check (key_hash is null or key_hash ~ '^[0-9a-f]{64}$'),
  enabled               boolean not null default true,
  time_mode             text not null default 'real' check (time_mode in ('real', 'demo')),
  history_minutes       integer not null default 15 check (history_minutes between 1 and 1440),
  offline_after_minutes integer not null default 35 check (offline_after_minutes between 1 and 10080),
  last_seen_at          timestamptz,
  last_result           jsonb,
  created_at            timestamptz not null default now()
);
create index if not exists gateways_orchard_id_idx on gateways (orchard_id);
comment on table gateways is
  'The computer on the farm (Node-RED) that sends the readings of the boxes of ONE orchard.';
comment on column gateways.key_hash is 'sha256 (hex) of the secret key. The key itself is never stored.';
comment on column gateways.time_mode is
  'real = the boxes send real times; demo = Node-RED simulation (its clock runs fast).';
comment on column gateways.history_minutes is 'One history point per box every N minutes of measured time.';
comment on column gateways.offline_after_minutes is 'A box is offline when nothing was received for N minutes.';


-- ---------- 6) The readings ----------
create table if not exists node_latest (
  node_id            uuid primary key references nodes(id) on delete cascade,
  gateway_id         uuid references gateways(id) on delete set null,
  measured_at        timestamptz not null,
  received_at        timestamptz not null default now(),
  soil_moisture_pct  real,
  soil_temp_c        real,
  air_temp_c         real,
  humidity_pct       real,
  light_par          real,
  vpd_kpa            real,
  battery_pct        real,
  rssi_dbm           smallint,
  water_stress       smallint,
  heat_stress        smallint,
  anomaly            real,
  drying_rate_pct_h  real,
  hours_above_35c    real,
  packets_lost       integer,
  level              text not null check (level = any (public.iot_levels())),
  faults             text[] not null default '{}' check (faults <@ public.iot_fault_codes()),
  reasons            text[] not null default '{}' check (reasons <@ public.iot_reason_codes()),
  cause              text check (cause is null or cause in ('water', 'heat', 'sensor')),
  confidence         real,
  seq                integer,
  firmware           text,
  model              text,
  history_at         timestamptz
);
comment on table node_latest is 'The last reading of each sensor box (written only by iot_ingest).';

create table if not exists node_readings (
  id                 bigint generated always as identity primary key,
  node_id            uuid not null references nodes(id) on delete cascade,
  measured_at        timestamptz not null,
  received_at        timestamptz not null default now(),
  soil_moisture_pct  real,
  soil_temp_c        real,
  air_temp_c         real,
  humidity_pct       real,
  light_par          real,
  vpd_kpa            real,
  battery_pct        real,
  rssi_dbm           smallint,
  water_stress       smallint,
  heat_stress        smallint,
  anomaly            real,
  drying_rate_pct_h  real,
  hours_above_35c    real,
  packets_lost       integer,
  level              text not null check (level = any (public.iot_levels())),
  faults             text[] not null default '{}' check (faults <@ public.iot_fault_codes()),
  unique (node_id, measured_at)
);
comment on table node_readings is
  'History of each box for the charts: 1 point every gateways.history_minutes (written only by iot_ingest).';

create table if not exists node_alert_events (
  id                 bigint generated always as identity primary key,
  node_id            uuid not null references nodes(id) on delete cascade,
  measured_at        timestamptz not null,
  received_at        timestamptz not null default now(),
  level              text not null check (level = any (public.iot_levels())),
  previous_level     text check (previous_level is null or previous_level = any (public.iot_levels())),
  reasons            text[] not null default '{}' check (reasons <@ public.iot_reason_codes()),
  cause              text check (cause is null or cause in ('water', 'heat', 'sensor')),
  confidence         real,
  water_stress       smallint,
  heat_stress        smallint,
  anomaly            real,
  soil_moisture_pct  real,
  air_temp_c         real,
  faults             text[] not null default '{}' check (faults <@ public.iot_fault_codes())
);
create index if not exists node_alert_events_node_time_idx on node_alert_events (node_id, measured_at desc);
comment on table node_alert_events is 'Alert log: one row each time the level of a box changes.';

create table if not exists node_fault_days (
  node_id   uuid not null references nodes(id) on delete cascade,
  day       date not null,
  code      text not null check (code = any (public.iot_fault_codes())),
  count     integer not null default 1,
  first_at  timestamptz not null,
  last_at   timestamptz not null,
  primary key (node_id, day, code)
);
comment on table node_fault_days is
  'Sensor problems: how many readings of a box had this fault code that day (Tunisia time).';


-- ---------- 7) The ingest (called ONLY by the Edge Function iot-ingest) ----------
-- p_key_hash: sha256 (hex) of the key the gateway sent. p_batch:
--   {"gateway": "GW-01", "readings": [
--     {"device": "NODE-02", "measured_at": "2026-06-15T04:00:00Z", "seq": 12,
--      "soil_moisture_pct": 24.1, "soil_temp_c": 22.3, "air_temp_c": 19.8,
--      "humidity_pct": 71.0, "light_par": 0, "vpd_kpa": 0.66, "battery_pct": 93.1,
--      "rssi_dbm": -79, "water_stress": 58, "heat_stress": 0, "anomaly": null,
--      "drying_rate_pct_h": 0.4, "hours_above_35c": 0, "packets_lost": 0,
--      "level": "watch", "reasons": ["water_stress"], "cause": "water",
--      "confidence": 0.62, "faults": [], "firmware": "1.2.0", "model": "rules-v1"}, ...]}
-- Returns {"accepted", "history", "events", "old", "restarts", "refused": {reason: n},
--          "refused_devices": {code: reason}}.
-- Errors: PT401 unknown or disabled key, PT503 ingest turned off, 22023 bad batch.
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
  -- "for update": two batches of the same gateway never run at the same time.
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
  -- The farmer of this orchard has a running paid pack.
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
      -- Only the boxes of THIS gateway's orchard.
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
    -- Demo: the simulated clock went back (Node-RED restarted without its
    -- memory) -> the history of this box starts again.
    if lat.node_id is not null and gw.time_mode = 'demo' and t_meas < lat.measured_at - interval '1 day' then
      delete from node_readings where node_id = nid;
      delete from node_alert_events where node_id = nid;
      delete from node_fault_days where node_id = nid;
      delete from node_latest where node_id = nid;
      lat := null;
      restarts := restarts + 1;
    end if;
    -- Already received (a batch sent twice) or older than the last one.
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

    -- Alert log: the level changed (the very first reading: only if not ok).
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

    -- Sensor problems, counted per day (Tunisia time).
    if cardinality(flt) > 0 then
      insert into node_fault_days (node_id, day, code, count, first_at, last_at)
      select nid, (t_meas at time zone 'Africa/Tunis')::date, c, 1, t_meas, t_meas from unnest(flt) as c
      on conflict (node_id, day, code) do update
        set count = node_fault_days.count + 1,
            last_at = greatest(node_fault_days.last_at, excluded.last_at);
    end if;

    -- History: one point every history_minutes of measured time.
    hist_at := lat.history_at;
    if hist_at is null or t_meas >= hist_at + make_interval(mins => gw.history_minutes) * 0.9 then
      insert into node_readings (node_id, measured_at, soil_moisture_pct, soil_temp_c, air_temp_c,
                                 humidity_pct, light_par, vpd_kpa, battery_pct, rssi_dbm, water_stress,
                                 heat_stress, anomaly, drying_rate_pct_h, hours_above_35c, packets_lost,
                                 level, faults)
      values (nid, t_meas, public.iot_num(r, 'soil_moisture_pct'), public.iot_num(r, 'soil_temp_c'),
              public.iot_num(r, 'air_temp_c'), public.iot_num(r, 'humidity_pct'),
              public.iot_num(r, 'light_par'), public.iot_num(r, 'vpd_kpa'),
              public.iot_num(r, 'battery_pct'), round(public.iot_num(r, 'rssi_dbm')),
              round(public.iot_num(r, 'water_stress')), round(public.iot_num(r, 'heat_stress')),
              public.iot_num(r, 'anomaly'), public.iot_num(r, 'drying_rate_pct_h'),
              public.iot_num(r, 'hours_above_35c'), round(public.iot_num(r, 'packets_lost')),
              lvl, flt)
      on conflict (node_id, measured_at) do nothing;
      hist_at := t_meas;
      stored := stored + 1;
    end if;

    -- The last reading of the box.
    insert into node_latest (node_id, gateway_id, measured_at, received_at, soil_moisture_pct, soil_temp_c,
                             air_temp_c, humidity_pct, light_par, vpd_kpa, battery_pct, rssi_dbm,
                             water_stress, heat_stress, anomaly, drying_rate_pct_h, hours_above_35c,
                             packets_lost, level, faults, reasons, cause, confidence, seq, firmware,
                             model, history_at)
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
            hist_at)
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
      firmware = excluded.firmware, model = excluded.model, history_at = excluded.history_at;
  end loop;

  -- The boxes that sent: online, received now (real time), battery.
  update nodes n set
    status = 'online',
    last_seen = now(),
    battery = coalesce(greatest(0, least(100, round(l.battery_pct)))::integer, n.battery)
  from node_latest l
  where l.node_id = n.id and n.id = any (touched);
  -- Known boxes that were refused (e.g. installation not accepted yet).
  update nodes n set last_refused_at = now(), last_refused_reason = refused_box ->> n.id::text
  where refused_box ? n.id::text;
  -- Keep iot_history_days of measured time per box.
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


-- ---------- 8) Admins: accept / remove a box, new gateway key ----------
-- These run with the rights of the person who calls them (RLS applies):
-- only admins (or the SQL Editor) can change nodes, kit_requests, gateways.

-- "Accepter l'installation": the box may now send. p_device_code = the code
-- printed on the box (may be left empty if the box already has one).
-- When every box of the orchard is accepted, its installation visit is done.
create or replace function public.iot_accept_node(p_node uuid, p_device_code text default null)
returns nodes
language plpgsql set search_path = public as $$
declare
  code   text := nullif(upper(btrim(p_device_code)), '');
  n      nodes;
  oid    uuid;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if code is not null and code !~ '^[A-Z0-9][A-Z0-9_-]{1,39}$' then
    raise exception 'Device code: 2 to 40 capital letters, digits, - or _' using errcode = '22023';
  end if;
  select z.orchard_id into oid
  from nodes x join zones z on z.id = x.zone_id
  where x.id = p_node and z.archived_at is null;
  if oid is null then
    raise exception 'Unknown box (or its zone was removed)' using errcode = 'P0002';
  end if;
  begin
    update nodes set
      hardware_id  = coalesce(code, hardware_id),
      installed_at = coalesce(installed_at, now()),
      installed_by = case when installed_at is null then auth.uid() else installed_by end
    where id = p_node
    returning * into n;
  exception when unique_violation then
    raise exception 'The device code % is already used by another box', code using errcode = '23505';
  end;
  if n.id is null then
    raise exception 'Unknown box' using errcode = 'P0002';
  end if;
  if n.hardware_id is null then
    raise exception 'Give the device code of the box' using errcode = '22023';
  end if;
  if not exists (select 1 from nodes x join zones z on z.id = x.zone_id
                 where z.orchard_id = oid and z.archived_at is null and x.installed_at is null) then
    update kit_requests set status = 'installed'
    where orchard_id = oid and status in ('new', 'contacted');
  end if;
  return n;
end;
$$;

-- "Retirer l'acceptation": the box is waiting again (its readings are refused).
-- Its history stays.
create or replace function public.iot_unaccept_node(p_node uuid)
returns nodes
language plpgsql set search_path = public as $$
declare
  n nodes;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  update nodes set installed_at = null, installed_by = null, status = 'offline'
  where id = p_node
  returning * into n;
  if n.id is null then
    raise exception 'Unknown box' using errcode = 'P0002';
  end if;
  return n;
end;
$$;

-- A NEW secret key for a gateway (the old one stops working at once).
-- Shown only here: paste it in the gateway's .env (LOOZ_GATEWAY_KEY).
create or replace function public.iot_gateway_new_key(p_code text)
returns text
language plpgsql set search_path = public as $$
declare
  new_key text := 'lgw_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  gid     uuid;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  update gateways set key_hash = encode(sha256(convert_to(new_key, 'UTF8')), 'hex')
  where code = upper(btrim(p_code))
  returning id into gid;
  if gid is null then
    raise exception 'Unknown gateway %', p_code using errcode = 'P0002';
  end if;
  return new_key;
end;
$$;


-- ---------- 9) The state of every box (admin dashboard, later the app) ----------
-- status: waiting (installation not accepted), installed (accepted, nothing
-- received yet), offline (nothing for offline_after_minutes), sensor_problem
-- (a fault code or the level "sensor"), online.
-- "security_invoker": the rules (RLS) of the person asking apply.
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
  end                   as status
from nodes n
join zones z on z.id = n.zone_id and z.archived_at is null
join orchards o on o.id = z.orchard_id
left join node_latest l on l.node_id = n.id
left join lateral (
  select gg.* from gateways gg where gg.orchard_id = o.id
  order by gg.last_seen_at desc nulls last, gg.created_at limit 1
) g on true;


-- ---------- 10) The rules (RLS) and rights ----------
alter table gateways          enable row level security;
alter table node_latest       enable row level security;
alter table node_readings     enable row level security;
alter table node_alert_events enable row level security;
alter table node_fault_days   enable row level security;

drop policy if exists "Admins manage gateways" on gateways;
create policy "Admins manage gateways"
  on gateways for all to authenticated using (is_admin()) with check (is_admin());

drop policy if exists "Admins see all latest readings" on node_latest;
create policy "Admins see all latest readings"
  on node_latest for select to authenticated using (is_admin());
drop policy if exists "Farmers see the latest readings of their boxes" on node_latest;
create policy "Farmers see the latest readings of their boxes"
  on node_latest for select to authenticated using (owns_node(node_id) and has_plan('paid'));

drop policy if exists "Admins see all readings" on node_readings;
create policy "Admins see all readings"
  on node_readings for select to authenticated using (is_admin());
drop policy if exists "Farmers see the readings of their boxes" on node_readings;
create policy "Farmers see the readings of their boxes"
  on node_readings for select to authenticated using (owns_node(node_id) and has_plan('paid'));

drop policy if exists "Admins see all alert events" on node_alert_events;
create policy "Admins see all alert events"
  on node_alert_events for select to authenticated using (is_admin());
drop policy if exists "Farmers see the alert events of their boxes" on node_alert_events;
create policy "Farmers see the alert events of their boxes"
  on node_alert_events for select to authenticated using (owns_node(node_id) and has_plan('paid'));

drop policy if exists "Admins see all sensor problems" on node_fault_days;
create policy "Admins see all sensor problems"
  on node_fault_days for select to authenticated using (is_admin());
drop policy if exists "Farmers see the sensor problems of their boxes" on node_fault_days;
create policy "Farmers see the sensor problems of their boxes"
  on node_fault_days for select to authenticated using (owns_node(node_id) and has_plan('paid'));

-- Nobody writes the readings by hand (only iot_ingest). Visitors see nothing.
revoke all on gateways, node_latest, node_readings, node_alert_events, node_fault_days
  from anon, authenticated;
grant select on node_latest, node_readings, node_alert_events, node_fault_days to authenticated;
grant select, insert, update, delete on gateways to authenticated;   -- RLS: admins only
grant all on gateways, node_latest, node_readings, node_alert_events, node_fault_days to service_role;
revoke all on public.iot_node_status from anon, authenticated;
grant select on public.iot_node_status to authenticated, service_role;

revoke all on function public.iot_ingest(text, jsonb) from public, anon, authenticated;
grant execute on function public.iot_ingest(text, jsonb) to service_role;
revoke all on function public.iot_accept_node(uuid, text)   from public, anon;
revoke all on function public.iot_unaccept_node(uuid)       from public, anon;
revoke all on function public.iot_gateway_new_key(text)     from public, anon;
grant execute on function public.iot_accept_node(uuid, text) to authenticated, service_role;
grant execute on function public.iot_unaccept_node(uuid)     to authenticated, service_role;
grant execute on function public.iot_gateway_new_key(text)   to authenticated, service_role;


-- ---------- 11) Last check: you should see  true | 30 | false | false | true | true | true ----------
select
  (select iot_ingest_enabled from app_settings where id)                                 as ingest_on,
  (select iot_history_days from app_settings where id)                                   as history_days,
  has_function_privilege('anon', 'public.iot_ingest(text, jsonb)', 'execute')            as visitors_can_send,
  has_function_privilege('authenticated', 'public.iot_ingest(text, jsonb)', 'execute')   as users_can_send,
  has_function_privilege('service_role', 'public.iot_ingest(text, jsonb)', 'execute')    as edge_function_can_send,
  (select bool_and(relrowsecurity) from pg_class
   where relname in ('gateways', 'node_latest', 'node_readings', 'node_alert_events', 'node_fault_days')
     and relnamespace = 'public'::regnamespace)                                          as rules_on,
  exists (select 1 from pg_indexes where schemaname = 'public'
          and indexname = 'nodes_hardware_id_unique')                                    as one_box_per_code;
