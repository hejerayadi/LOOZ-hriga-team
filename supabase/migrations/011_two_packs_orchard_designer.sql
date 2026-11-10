-- =========================================================
-- LOOZ — Migration 011: TWO packs (Free / Paid per node) + the ORCHARD DESIGNER
--
-- What it does:
--   1. Only TWO packs now:
--        free = community + regional alerts (never pays)
--        paid = 3D orchard, predictions, photo diagnosis (CV), assistant /
--               voice. Price = 8 DT per NODE for 30 days (plan_prices).
--      1 node = 1 zone of the orchard. Essential and Connected are removed:
--      their subscribers become "paid" (nothing is lost), open LOOZ kit
--      requests of the old Connected flow are cancelled with a note.
--   2. The bill: billed nodes = the zones the farmer drew, but at least
--      1 node per app_settings.hectares_per_node hectares (2 ha at first:
--      drawing 1 zone on 10 ha still bills 5 nodes). An admin can write
--      the real number of installed nodes (orchards.confirmed_nodes): it
--      replaces the area minimum. Set hectares_per_node to empty (null) to
--      bill only the zones drawn.
--   3. The orchard designer: the farmer's drawing is saved as a DRAFT
--      (orchards.design) after every step, so he resumes where he stopped.
--      Once paid, orchard_apply_design() builds the orchard: outline and
--      area, zones (reused table, + type, colour, number of trees), one
--      sensor node per zone (reused table) and the trees in rows. Editing
--      later = a new draft applied the same way: nothing with a history
--      (photos, alerts, advice) is deleted, it is archived.
--   4. Security: the app can only save its draft, ask the price, pay (demo)
--      and apply. Orchards, zones, nodes, trees, packs and node numbers are
--      written ONLY by the functions of this file. Free users see their
--      draft; zones / nodes / trees / photos need the paid pack.
--   5. last check
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 010. Safe to run again (no begin/commit, each
-- statement can be run again).
-- ⚠ If you ever re-run looz_policies.sql, 002, 003 or 004, run THIS file
--   again afterwards: they recreate rules with the old pack names.
-- =========================================================


-- ---------- 1) The bill: hectares per node (admin setting) ----------
alter table app_settings
  add column if not exists hectares_per_node numeric(7, 2) default 2.00;
alter table app_settings drop constraint if exists app_settings_hectares_per_node_check;
alter table app_settings add constraint app_settings_hectares_per_node_check
  check (hectares_per_node is null or hectares_per_node between 0.10 and 1000);
comment on column app_settings.hectares_per_node is
  'Billing minimum: at least 1 node per this many hectares of orchard (empty = only the zones drawn).';


-- ---------- 2) Two packs: 'free' and 'paid' ----------

-- 2a) Rank of a pack. The old names count as 'paid' (old rules / old app).
create or replace function public.plan_rank(p text) returns integer
language sql immutable as $$
  select case p when 'free' then 0 when 'paid' then 1
                when 'essential' then 1 when 'connected' then 1 end;
$$;

-- 2b) Subscriptions: Essential / Connected -> paid, with their nodes
--     (Connected: the sensors last paid; Essential: 1 node).
alter table subscriptions add column if not exists nodes integer;
alter table subscriptions drop constraint if exists subscriptions_nodes_check;
alter table subscriptions add constraint subscriptions_nodes_check
  check (nodes is null or nodes between 1 and 100);
comment on column subscriptions.nodes is
  'Nodes paid for the current period (empty = no limit, e.g. given by an admin).';

alter table subscriptions drop constraint if exists subscriptions_plan_check;
update subscriptions s set
  nodes = least(100, coalesce(s.nodes,
                   (select p.sensors_or_nodes from (
                      select coalesce(to_jsonb(pay) ->> 'nodes', to_jsonb(pay) ->> 'sensors')::integer
                             as sensors_or_nodes, pay.paid_at
                      from payments pay
                      where pay.user_id = s.user_id and pay.plan = 'connected'
                        and pay.status in ('paid', 'paid_demo')) p
                    where p.sensors_or_nodes is not null
                    order by p.paid_at desc nulls last limit 1),
                   1)),
  plan = 'paid'
where s.plan in ('essential', 'connected');
alter table subscriptions add constraint subscriptions_plan_check
  check (plan in ('free', 'paid'));

-- 2c) The pack chosen at sign-up.
alter table profiles drop constraint if exists profiles_chosen_plan_check;
update profiles set chosen_plan = 'paid' where chosen_plan in ('essential', 'connected');
alter table profiles add constraint profiles_chosen_plan_check
  check (chosen_plan in ('free', 'paid'));

-- 2d) The price: ONE paid pack, per node (old Connected price kept).
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public'
             and table_name = 'plan_prices' and column_name = 'per_sensor') then
    alter table plan_prices rename column per_sensor to per_node;
  end if;
end $$;
alter table plan_prices drop constraint if exists plan_prices_plan_check;
insert into plan_prices (plan, price_millimes, period_days, per_node)
select 'paid', coalesce((select price_millimes from plan_prices where plan = 'connected'), 8000), 30, true
on conflict (plan) do nothing;
delete from plan_prices where plan in ('essential', 'connected');
alter table plan_prices add constraint plan_prices_plan_check check (plan = 'paid');
comment on column plan_prices.per_node is
  'true = the price is for ONE node (= one zone of the orchard) for period_days days.';

-- 2e) Payments: the old ones keep their pack name (history).
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public'
             and table_name = 'payments' and column_name = 'sensors') then
    alter table payments rename column sensors to nodes;
  end if;
  if exists (select 1 from pg_constraint where conname = 'payments_sensors_check') then
    alter table payments rename constraint payments_sensors_check to payments_nodes_check;
  end if;
end $$;
alter table payments drop constraint if exists payments_plan_check;
alter table payments add constraint payments_plan_check
  check (plan in ('paid', 'essential', 'connected'));
alter table payments add column if not exists kind text not null default 'period';
alter table payments drop constraint if exists payments_kind_check;
alter table payments add constraint payments_kind_check
  check (kind in ('period', 'extra_nodes'));
comment on column payments.kind is
  'period = the pack for period_days days; extra_nodes = more nodes until the end of the period already paid.';

-- 2f) The old sign-up choice: 'essential' / 'connected' still mean 'paid'.
create or replace function public.choose_plan(p_plan text) returns void
language plpgsql security definer set search_path = public as $$
declare
  wanted text := case when p_plan in ('essential', 'connected') then 'paid' else p_plan end;
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if wanted is null or wanted not in ('free', 'paid') then
    raise exception 'Unknown plan' using errcode = '22023';
  end if;
  update profiles set
    payment_status = case
      when wanted = 'free' then 'free'
      when payment_status = 'paid' and chosen_plan = wanted then 'paid'
      else 'pending' end,
    chosen_plan    = wanted,
    plan_chosen_at = now()
  where id = auth.uid();
end;
$$;
revoke execute on function public.choose_plan(text) from public, anon;
grant execute on function public.choose_plan(text) to authenticated;


-- ---------- 3) Geometry: polygons in metres ----------
-- A polygon = [{"x": 0, "z": 0}, ...]: corners in METRES, in the same frame
-- for both drawing modes (x = east, z = south, like the 3D scene). The map
-- mode also keeps the GPS point of (0, 0): orchards.origin_lat / origin_lng.

-- Area in m² (shoelace formula).
create or replace function public.polygon_area_m2(p jsonb) returns double precision
language sql immutable as $$
  with pts as (
    select (e ->> 'x')::float8 as x, (e ->> 'z')::float8 as z, i
    from jsonb_array_elements(p) with ordinality as t(e, i)
  ), n as (select count(*) as c from pts)
  select abs(sum(a.x * b.z - b.x * a.z)) / 2
  from pts a join pts b on b.i = (a.i % (select c from n)) + 1;
$$;

-- 3 to 200 corners, numbers, inside ±5 km, at least 10 m², no edges crossing.
create or replace function public.polygon_ok(p jsonb) returns boolean
language plpgsql immutable as $$
declare
  n int; e jsonb; xs float8[] := '{}'; zs float8[] := '{}';
  i int; j int; ax float8; az float8; bx float8; bz float8;
  cx float8; cz float8; dx float8; dz float8; d1 float8; d2 float8; d3 float8; d4 float8;
begin
  if p is null or jsonb_typeof(p) <> 'array' then return false; end if;
  n := jsonb_array_length(p);
  if n < 3 or n > 200 then return false; end if;
  for e in select value from jsonb_array_elements(p) loop
    if jsonb_typeof(e) <> 'object' or jsonb_typeof(e -> 'x') is distinct from 'number'
       or jsonb_typeof(e -> 'z') is distinct from 'number' then
      return false;
    end if;
    if abs((e ->> 'x')::float8) > 5000 or abs((e ->> 'z')::float8) > 5000 then return false; end if;
    xs := xs || (e ->> 'x')::float8;
    zs := zs || (e ->> 'z')::float8;
  end loop;
  if public.polygon_area_m2(p) < 10 then return false; end if;
  -- No two edges may cross (edges side by side share a corner: skipped).
  for i in 1 .. n loop
    ax := xs[i]; az := zs[i]; bx := xs[i % n + 1]; bz := zs[i % n + 1];
    for j in i + 2 .. n loop
      if i = 1 and j = n then continue; end if;
      cx := xs[j]; cz := zs[j]; dx := xs[j % n + 1]; dz := zs[j % n + 1];
      d1 := (dx - cx) * (az - cz) - (dz - cz) * (ax - cx);
      d2 := (dx - cx) * (bz - cz) - (dz - cz) * (bx - cx);
      d3 := (bx - ax) * (cz - az) - (bz - az) * (cx - ax);
      d4 := (bx - ax) * (dz - az) - (bz - az) * (dx - ax);
      if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0))
         and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)) then
        return false;
      end if;
    end loop;
  end loop;
  return true;
end;
$$;


-- ---------- 4) ORCHARDS (reused table): outline, area, draft, status ----------
alter table orchards alter column name set default '';
alter table orchards add column if not exists status         text not null default 'draft';
alter table orchards add column if not exists draw_mode      text;
alter table orchards add column if not exists outline        jsonb;
alter table orchards add column if not exists origin_lat     double precision;
alter table orchards add column if not exists origin_lng     double precision;
alter table orchards add column if not exists tree_spacing_m real not null default 7;
alter table orchards add column if not exists design         jsonb;
alter table orchards add column if not exists confirmed_nodes integer;
alter table orchards add column if not exists is_demo        boolean not null default false;
alter table orchards add column if not exists created_at     timestamptz not null default now();
alter table orchards add column if not exists updated_at     timestamptz not null default now();
alter table orchards add column if not exists completed_at   timestamptz;

comment on column orchards.area is 'Hectares, computed by the database from the outline.';
comment on column orchards.outline is 'Corners in metres [{"x","z"}] (both drawing modes).';
comment on column orchards.design is
  'The DRAFT of the designer (saved after every step; empty = nothing pending).';
comment on column orchards.confirmed_nodes is
  'ADMIN ONLY: nodes really installed. Replaces the area minimum of the bill.';

alter table orchards drop constraint if exists orchards_status_check;
alter table orchards add constraint orchards_status_check
  check (status in ('draft', 'complete') and (status = 'draft' or outline is not null));
alter table orchards drop constraint if exists orchards_draw_mode_check;
alter table orchards add constraint orchards_draw_mode_check
  check (draw_mode is null or draw_mode in ('map', 'grid'));
alter table orchards drop constraint if exists orchards_outline_check;
alter table orchards add constraint orchards_outline_check
  check (outline is null or public.polygon_ok(outline));
alter table orchards drop constraint if exists orchards_origin_check;
alter table orchards add constraint orchards_origin_check
  check ((origin_lat is null and origin_lng is null)
         or (origin_lat between -90 and 90 and origin_lng between -180 and 180));
alter table orchards drop constraint if exists orchards_spacing_check;
alter table orchards add constraint orchards_spacing_check
  check (tree_spacing_m between 3 and 15);
alter table orchards drop constraint if exists orchards_design_check;
alter table orchards add constraint orchards_design_check
  check (design is null or (jsonb_typeof(design) = 'object' and octet_length(design::text) <= 300000));
alter table orchards drop constraint if exists orchards_confirmed_nodes_check;
alter table orchards add constraint orchards_confirmed_nodes_check
  check (confirmed_nodes is null or confirmed_nodes between 1 and 100);

-- ONE orchard per farmer (created only if nobody has two already).
do $$
begin
  if not exists (select 1 from orchards group by farmer_id having count(*) > 1) then
    create unique index if not exists orchards_one_per_farmer on orchards (farmer_id);
  else
    raise notice 'Some farmers have several orchards: the one-orchard rule is not added.';
  end if;
end $$;

-- The area (hectares) always comes from the outline, never from the app.
create or replace function public.orchards_before_write() returns trigger
language plpgsql set search_path = public as $$
begin
  new.area := case when new.outline is null then null
                   else round((public.polygon_area_m2(new.outline) / 10000)::numeric, 4) end;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists orchards_before_write on orchards;
create trigger orchards_before_write
  before insert or update on orchards
  for each row execute function public.orchards_before_write();


-- ---------- 5) ZONES (reused table) = the nodes of the bill ----------
alter table zones alter column name set default '';
alter table zones add column if not exists letter      text;
alter table zones add column if not exists zone_type   text;
alter table zones add column if not exists color       text;
alter table zones add column if not exists tree_count  integer;
alter table zones add column if not exists archived_at timestamptz;

alter table zones drop constraint if exists zones_letter_check;
alter table zones add constraint zones_letter_check check (letter is null or letter ~ '^[A-T]$');
alter table zones drop constraint if exists zones_zone_type_check;
alter table zones add constraint zones_zone_type_check check (zone_type is null or zone_type in
  ('young_trees', 'old_trees', 'sandy_soil', 'irrigated', 'rainfed', 'other'));
alter table zones drop constraint if exists zones_color_check;
alter table zones add constraint zones_color_check check (color is null or color ~ '^#[0-9a-fA-F]{6}$');
alter table zones drop constraint if exists zones_tree_count_check;
alter table zones add constraint zones_tree_count_check check (tree_count is null or tree_count between 0 and 20000);
comment on column zones.name is 'The farmer''s own name of the zone (empty = "Zone A" in his language).';
comment on column zones.archived_at is
  'Removed by an edit of the orchard: kept with its history, not shown, not billed.';

create unique index if not exists zones_one_letter
  on zones (orchard_id, letter) where archived_at is null and letter is not null;

-- NODES (reused table): one per zone; installed by a technician.
alter table nodes add column if not exists installed_at timestamptz;
alter table nodes add column if not exists hardware_id  text;
comment on column nodes.installed_at is 'Set when the technician installed the box (empty = waiting).';

-- TREES (reused table): placed by the database, archived when they have history.
alter table trees add column if not exists archived_at timestamptz;


-- ---------- 6) The LOOZ kit requests = installation visits ----------
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public'
             and table_name = 'kit_requests' and column_name = 'sensors') then
    alter table kit_requests rename column sensors to nodes;
  end if;
end $$;
alter table kit_requests add column if not exists orchard_id uuid references orchards(id) on delete set null;
comment on table kit_requests is
  'Installation visits of the sensor nodes: made by the database when a paid orchard has nodes '
  'to install. An admin calls the farmer, installs, then sets status = installed.';

-- The old Connected flow (a request without orchard): cancelled, with a note.
update kit_requests
set status = 'cancelled',
    admin_note = concat_ws(' | ', admin_note,
      'Migration 011: the Connected pack was removed. The farmer now draws his orchard and '
      'pays per zone; paying creates a new installation request.')
where status in ('new', 'contacted') and orchard_id is null;

-- The farmer does not ask for a kit any more (paying for the orchard does).
drop function if exists public.request_kit();

-- "installed" -> every waiting node of the orchard is installed.
create or replace function public.kit_requests_install_nodes() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'installed' and old.status is distinct from 'installed' and new.orchard_id is not null then
    update nodes n set installed_at = coalesce(n.installed_at, now())
    from zones z
    where z.id = n.zone_id and z.orchard_id = new.orchard_id and z.archived_at is null;
  end if;
  return new;
end;
$$;
drop trigger if exists kit_requests_install_nodes on kit_requests;
create trigger kit_requests_install_nodes
  after update on kit_requests
  for each row execute function public.kit_requests_install_nodes();


-- ---------- 7) Checking a draft of the designer ----------
-- The draft: {"step", "mode": "grid"|"map", "name", "outline": [...],
--   "origin": {"lat", "lng"}, "spacing": 7, "zone_method": "auto"|"draw",
--   "zones": [{"id" (an existing zone, when editing), "letter": "A", "name",
--              "type", "color", "boundary": [...], "tree_count"}]}
-- Returns what is wrong (null = fine). complete = false: a draft may be
-- unfinished; true: everything needed to build the orchard.
create or replace function public.orchard_design_problem(d jsonb, complete boolean)
returns text
language plpgsql stable set search_path = public as $$
declare
  z jsonb;
  letters text[] := '{}';
  zone_area float8 := 0;
begin
  if d is null or jsonb_typeof(d) <> 'object' then return 'design: not an object'; end if;
  if octet_length(d::text) > 300000 then return 'design: too big'; end if;
  if d ? 'mode' and coalesce(d ->> 'mode', '') not in ('map', 'grid') then return 'mode: map or grid'; end if;
  if d ? 'step' and coalesce(d ->> 'step', '') not in ('outline', 'zones', 'review') then return 'step: outline, zones or review'; end if;
  if d ? 'zone_method' and coalesce(d ->> 'zone_method', '') not in ('auto', 'draw') then return 'zone_method: auto or draw'; end if;
  if d ? 'name' and (jsonb_typeof(d -> 'name') <> 'string'
       or (d ->> 'name' <> '' and not public.community_text_ok(d ->> 'name', 40))) then
    return 'name: up to 40 letters';
  end if;
  if d ? 'spacing' and (jsonb_typeof(d -> 'spacing') <> 'number' or (d ->> 'spacing')::float8 not between 3 and 15) then
    return 'spacing: 3 to 15 m';
  end if;
  if d ? 'origin' and jsonb_typeof(d -> 'origin') <> 'null' and (
       jsonb_typeof(d -> 'origin') <> 'object'
       or jsonb_typeof(d -> 'origin' -> 'lat') is distinct from 'number'
       or jsonb_typeof(d -> 'origin' -> 'lng') is distinct from 'number'
       or (d -> 'origin' ->> 'lat')::float8 not between -90 and 90
       or (d -> 'origin' ->> 'lng')::float8 not between -180 and 180) then
    return 'origin: GPS lat / lng';
  end if;
  if d ? 'outline' and jsonb_typeof(d -> 'outline') not in ('array', 'null') then return 'outline: a list of corners'; end if;
  if d ? 'zones' and (jsonb_typeof(d -> 'zones') <> 'array' or jsonb_array_length(d -> 'zones') > 20) then
    return 'zones: up to 20';
  end if;
  if not complete then return null; end if;

  -- Everything needed to build the orchard.
  if d ->> 'mode' is null then return 'mode missing'; end if;
  if not public.polygon_ok(d -> 'outline') then return 'outline: 3 to 200 corners, no crossing edges'; end if;
  if d ->> 'mode' = 'map' and jsonb_typeof(d -> 'origin') is distinct from 'object' then return 'origin missing (map mode)'; end if;
  if jsonb_typeof(d -> 'zones') is distinct from 'array' or jsonb_array_length(d -> 'zones') < 1 then
    return 'zones: 1 to 20';
  end if;
  for z in select value from jsonb_array_elements(d -> 'zones') loop
    if jsonb_typeof(z) <> 'object' then return 'zone: not an object'; end if;
    if coalesce(z ->> 'letter', '') !~ '^[A-T]$' or (z ->> 'letter') = any (letters) then
      return 'zone letter: A to T, each once';
    end if;
    letters := letters || (z ->> 'letter');
    if z ? 'id' and jsonb_typeof(z -> 'id') <> 'null'
       and coalesce(z ->> 'id', '') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      return 'zone id: a uuid';
    end if;
    if not public.polygon_ok(z -> 'boundary') then return 'zone ' || (z ->> 'letter') || ': bad boundary'; end if;
    if z ? 'tree_count' and jsonb_typeof(z -> 'tree_count') <> 'null' and (
         jsonb_typeof(z -> 'tree_count') <> 'number' or (z ->> 'tree_count')::numeric not between 0 and 20000
         or (z ->> 'tree_count')::numeric <> trunc((z ->> 'tree_count')::numeric)) then
      return 'zone ' || (z ->> 'letter') || ': trees 0 to 20000';
    end if;
    if z ? 'type' and jsonb_typeof(z -> 'type') <> 'null' and coalesce(z ->> 'type', '') not in
         ('young_trees', 'old_trees', 'sandy_soil', 'irrigated', 'rainfed', 'other') then
      return 'zone ' || (z ->> 'letter') || ': unknown type';
    end if;
    if z ? 'color' and jsonb_typeof(z -> 'color') <> 'null' and coalesce(z ->> 'color', '') !~ '^#[0-9a-fA-F]{6}$' then
      return 'zone ' || (z ->> 'letter') || ': colour #RRGGBB';
    end if;
    if z ? 'name' and jsonb_typeof(z -> 'name') <> 'null' and (jsonb_typeof(z -> 'name') <> 'string'
         or (z ->> 'name' <> '' and not public.community_text_ok(z ->> 'name', 30))) then
      return 'zone ' || (z ->> 'letter') || ': name up to 30 letters';
    end if;
    zone_area := zone_area + public.polygon_area_m2(z -> 'boundary');
  end loop;
  -- The zones share the outline (a little margin for rounding).
  if zone_area > public.polygon_area_m2(d -> 'outline') * 1.05 + 1 then
    return 'zones: bigger than the outline';
  end if;
  return null;
end;
$$;


-- ---------- 8) The bill ----------
-- What [p_user] pays now and every period for his orchard (his DRAFT if he
-- has one, otherwise the orchard as it is):
--   billed_nodes = the zones, at least 1 per hectares_per_node hectares
--                  (or the nodes an admin confirmed), never less than 1
--   kind = 'new'          no paid pack running: pay billed_nodes x price
--          'extra_nodes'  more nodes than paid: pay the extra nodes until
--                         the end of the period already paid
--          'covered'      nothing to pay now (the next period: monthly)
create or replace function public.orchard_quote_for(p_user uuid)
returns table (area_ha numeric, zones integer, min_nodes_by_area integer,
               billed_nodes integer, paid_nodes integer, price_per_node integer,
               period_days integer, monthly_millimes integer, kind text,
               due_now_millimes integer, ends_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  o        orchards;
  price    plan_prices;
  sub      subscriptions;
  problem  text;
  per_ha   numeric := (select s.hectares_per_node from app_settings s where s.id);
  ha       numeric;
  zc       integer;
  min_area integer;
  billed   integer;
  left_s   float8;
begin
  select * into o from orchards where farmer_id = p_user;
  if not found or (o.design is null and o.status <> 'complete') then
    raise exception 'Draw your orchard first' using errcode = 'PT409';
  end if;
  if o.design is not null then
    problem := public.orchard_design_problem(o.design, true);
    if problem is not null then
      raise exception 'The drawing is not finished: %', problem using errcode = 'PT409';
    end if;
    ha := round((public.polygon_area_m2(o.design -> 'outline') / 10000)::numeric, 4);
    zc := jsonb_array_length(o.design -> 'zones');
  else
    ha := o.area;
    zc := (select count(*) from zones z where z.orchard_id = o.id and z.archived_at is null);
  end if;
  select * into price from plan_prices where plan = 'paid';
  min_area := case when per_ha is null or ha is null then 0 else ceil(ha / per_ha)::integer end;
  billed := greatest(zc, coalesce(o.confirmed_nodes, min_area), 1);

  select * into sub from subscriptions s
  where s.user_id = p_user and s.plan = 'paid' and s.status = 'active'
    and (s.ends_at is null or s.ends_at > now());

  area_ha := round(ha, 2);
  zones := zc;
  min_nodes_by_area := min_area;
  billed_nodes := billed;
  price_per_node := price.price_millimes;
  period_days := price.period_days;
  monthly_millimes := price.price_millimes * case when price.per_node then billed else 1 end;
  if sub.user_id is null then
    paid_nodes := 0;
    kind := 'new';
    due_now_millimes := monthly_millimes;
  elsif sub.nodes is null or sub.nodes >= billed then
    paid_nodes := sub.nodes;
    kind := 'covered';
    due_now_millimes := 0;
    ends_at := sub.ends_at;
  else
    paid_nodes := sub.nodes;
    kind := 'extra_nodes';
    ends_at := sub.ends_at;
    -- The days left of the period already paid (no end = one whole period).
    left_s := case when sub.ends_at is null then price.period_days * 86400.0
                   else greatest(0, extract(epoch from sub.ends_at - now())) end;
    due_now_millimes := greatest(100, (ceil((billed - sub.nodes) * price.price_millimes
                          * least(1, left_s / (price.period_days * 86400.0)) / 100) * 100)::integer);
  end if;
  return next;
end;
$$;

-- The app: the bill of the logged-in farmer (the review step shows it).
create or replace function public.orchard_quote()
returns table (area_ha numeric, zones integer, min_nodes_by_area integer,
               billed_nodes integer, paid_nodes integer, price_per_node integer,
               period_days integer, monthly_millimes integer, kind text,
               due_now_millimes integer, ends_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  return query select * from public.orchard_quote_for(auth.uid());
end;
$$;


-- ---------- 9) Giving the pack (the ONE place) ----------
-- [p_days] more days of [p_plan] with [p_nodes] nodes. Same pack still
-- running: the days are added after its end. Never called by the app.
drop function if exists public.activate_pack(uuid, text, integer);
create or replace function public.activate_pack(p_user uuid, p_plan text, p_days integer, p_nodes integer)
returns timestamptz
language plpgsql security definer set search_path = public as $$
declare
  sub      subscriptions;
  new_end  timestamptz;
begin
  select * into sub from subscriptions where user_id = p_user for update;
  if sub.plan = p_plan and sub.status = 'active' and sub.ends_at > now() then
    new_end := sub.ends_at + make_interval(days => p_days);
  else
    new_end := now() + make_interval(days => p_days);
  end if;
  -- The profile first (its "paid" trigger of 005 would give the pack
  -- forever), then the subscription with its real end and its nodes.
  update profiles set chosen_plan = p_plan, payment_status = 'paid',
                      plan_chosen_at = coalesce(plan_chosen_at, now())
  where id = p_user;
  insert into subscriptions (user_id, plan, status, started_at, ends_at, nodes)
  values (p_user, p_plan, 'active', now(), new_end, p_nodes)
  on conflict (user_id) do update
    set plan = excluded.plan,
        status = 'active',
        started_at = case when subscriptions.plan = excluded.plan
                           and subscriptions.ends_at > now()
                          then subscriptions.started_at else now() end,
        ends_at = excluded.ends_at,
        nodes = excluded.nodes;
  return new_end;
end;
$$;

-- More nodes until the end of the period already paid.
create or replace function public.set_pack_nodes(p_user uuid, p_nodes integer) returns void
language sql security definer set search_path = public as $$
  update subscriptions set nodes = p_nodes
  where user_id = p_user and plan = 'paid' and status = 'active';
$$;

-- The old units of 009 (sensors of the kit): replaced by the bill above.
drop function if exists public.pack_units(uuid, text);


-- ---------- 10) Payments: demo (app) and real provider (server) ----------

-- The DEMO payment of the paid pack: the amount comes from the bill above,
-- never from the app. p_success = false: the test card that always fails.
-- Works ONLY if app_settings.demo_payments_enabled = true. At most 10 tries
-- per hour. 'essential' / 'connected' are taken as 'paid' (old app).
create or replace function public.demo_payment(p_plan text, p_success boolean default true)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  uid    uuid := auth.uid();
  q      record;
  price  plan_prices;
  result payments;
  extra  boolean;
begin
  if uid is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if not coalesce((select demo_payments_enabled from app_settings where id), false) then
    raise exception 'Demo payments are turned off' using errcode = 'PT403';
  end if;
  if p_plan is null or p_plan not in ('paid', 'essential', 'connected') then
    raise exception 'Unknown paid pack: %', p_plan using errcode = '22023';
  end if;
  select * into q from public.orchard_quote_for(uid);   -- PT409 if nothing drawn
  select * into price from plan_prices where plan = 'paid';
  if (select count(*) from payments
      where user_id = uid and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Too many payments: wait an hour' using errcode = 'PT429';
  end if;
  extra := q.kind = 'extra_nodes';
  insert into payments (user_id, plan, amount_millimes, period_days, provider, status,
                        nodes, kind, paid_at)
  values (uid, 'paid',
          case when extra then q.due_now_millimes else q.monthly_millimes end,
          case when extra then greatest(1, ceil(extract(epoch from q.ends_at - now()) / 86400.0)::integer)
               else price.period_days end,
          'demo',
          case when p_success then 'paid_demo' else 'failed_demo' end,
          q.billed_nodes,
          case when extra then 'extra_nodes' else 'period' end,
          case when p_success then now() end)
  returning * into result;
  if p_success then
    if extra then
      perform public.set_pack_nodes(uid, q.billed_nodes);
    else
      perform public.activate_pack(uid, 'paid', price.period_days, q.billed_nodes);
    end if;
  end if;
  return result;
end;
$$;

-- The real provider later (service_role only): same bill.
create or replace function public.start_payment(p_user uuid, p_plan text)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  q      record;
  price  plan_prices;
  result payments;
  extra  boolean;
begin
  if p_plan is null or p_plan not in ('paid', 'essential', 'connected') then
    raise exception 'Unknown paid pack: %', p_plan using errcode = '22023';
  end if;
  if not exists (select 1 from profiles where id = p_user) then
    raise exception 'Unknown user' using errcode = '22023';
  end if;
  select * into q from public.orchard_quote_for(p_user);
  select * into price from plan_prices where plan = 'paid';
  if (select count(*) from payments
      where user_id = p_user and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Too many payments: wait an hour' using errcode = 'PT429';
  end if;
  extra := q.kind = 'extra_nodes';
  insert into payments (user_id, plan, amount_millimes, period_days, nodes, kind)
  values (p_user, 'paid',
          case when extra then q.due_now_millimes else q.monthly_millimes end,
          case when extra then greatest(1, ceil(extract(epoch from q.ends_at - now()) / 86400.0)::integer)
               else price.period_days end,
          q.billed_nodes,
          case when extra then 'extra_nodes' else 'period' end)
  returning * into result;
  return result;
end;
$$;

create or replace function public.confirm_payment(p_ref text, p_amount integer)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  pay payments;
begin
  select * into pay from payments where provider_ref = p_ref for update;
  if not found then
    raise exception 'Unknown payment reference' using errcode = '22023';
  end if;
  if pay.status = 'paid' then
    return pay;
  end if;
  if p_amount is distinct from pay.amount_millimes then
    raise exception 'Wrong amount: % instead of %', p_amount, pay.amount_millimes
      using errcode = '22023';
  end if;
  if pay.user_id is null then
    raise exception 'The account of this payment was deleted' using errcode = '22023';
  end if;
  update payments set status = 'paid', paid_at = now(), updated_at = now()
  where id = pay.id
  returning * into pay;
  if pay.kind = 'extra_nodes' then
    perform public.set_pack_nodes(pay.user_id, pay.nodes);
  else
    perform public.activate_pack(pay.user_id, 'paid', pay.period_days, pay.nodes);
  end if;
  return pay;
end;
$$;


-- ---------- 11) The designer: draft, discard, build ----------

-- Saves the draft (after every step). The first save makes the orchard
-- (a draft: no zones, nothing billed). Farmers only, any pack.
create or replace function public.orchard_save_design(p_design jsonb)
returns orchards
language plpgsql security definer set search_path = public as $$
declare
  uid     uuid := auth.uid();
  problem text := public.orchard_design_problem(p_design, false);
  o       orchards;
begin
  if uid is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if (select role from profiles where id = uid) is distinct from 'farmer' then
    raise exception 'Only farmers have an orchard' using errcode = '42501';
  end if;
  if problem is not null then
    raise exception 'Wrong drawing: %', problem using errcode = '22023';
  end if;
  update orchards set design = p_design where farmer_id = uid returning * into o;
  if not found then
    insert into orchards (farmer_id, name, design) values (uid, coalesce(p_design ->> 'name', ''), p_design)
    returning * into o;
  end if;
  return o;
end;
$$;

-- Throws the draft away (an orchard never built is removed).
create or replace function public.orchard_discard_design() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  delete from orchards where farmer_id = auth.uid() and status = 'draft';
  update orchards set design = null where farmer_id = auth.uid();
end;
$$;

-- Plants the trees of one zone in rows, about tree_count trees (or the
-- orchard's spacing). Trees with history (photo, alert, advice) are
-- archived; the others are removed first.
create or replace function public.orchard_layout_zone(p_zone uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare
  z        zones;
  o        orchards;
  xs       float8[];
  zs       float8[];
  n        integer;
  minx float8; maxx float8; minz float8; maxz float8;
  zone_area float8;
  spacing  float8;
  x        float8;
  zz       float8;
  inside   boolean;
  i        integer;
  j        integer;
  next_code integer;
  added    integer := 0;
begin
  select * into z from zones where id = p_zone;
  select * into o from orchards where id = z.orchard_id;
  update trees t set archived_at = now()
  where t.zone_id = z.id and t.archived_at is null
    and (exists (select 1 from tree_photos p where p.tree_id = t.id)
      or exists (select 1 from advice a where a.tree_id = t.id)
      or exists (select 1 from alerts l where l.tree_id = t.id));
  delete from trees where zone_id = z.id and archived_at is null;
  if z.archived_at is not null then
    return 0;
  end if;

  select array_agg((e ->> 'x')::float8 order by k), array_agg((e ->> 'z')::float8 order by k)
  into xs, zs
  from jsonb_array_elements(z.boundary) with ordinality as t(e, k);
  n := array_length(xs, 1);
  select min(v), max(v) into minx, maxx from unnest(xs) v;
  select min(v), max(v) into minz, maxz from unnest(zs) v;
  zone_area := public.polygon_area_m2(z.boundary);
  spacing := case when coalesce(z.tree_count, 0) > 0
                  then greatest(3, least(15, sqrt(zone_area / z.tree_count)))
                  else o.tree_spacing_m end;
  if zone_area / (spacing * spacing) > 20000 then
    raise exception 'Too many trees in zone %', z.letter using errcode = '22023';
  end if;
  select coalesce(max(t.code::integer), 0) into next_code
  from trees t where t.orchard_id = o.id and t.code ~ '^[0-9]{1,6}$';

  -- Rows from the corner of the zone, half a spacing from its edge.
  zz := minz + spacing / 2;
  while zz < maxz loop
    x := minx + spacing / 2;
    while x < maxx loop
      inside := false;
      j := n;
      for i in 1 .. n loop
        if (zs[i] > zz) <> (zs[j] > zz)
           and x < (xs[j] - xs[i]) * (zz - zs[i]) / (zs[j] - zs[i]) + xs[i] then
          inside := not inside;
        end if;
        j := i;
      end loop;
      if inside then
        next_code := next_code + 1;
        added := added + 1;
        insert into trees (orchard_id, zone_id, code, pos_x, pos_z)
        values (o.id, z.id, next_code::text, round(x::numeric, 2), round(zz::numeric, 2));
      end if;
      x := x + spacing;
    end loop;
    zz := zz + spacing;
  end loop;
  return added;
end;
$$;

-- Builds (or changes) the orchard of [p_user] from his draft.
-- p_check = true (the app): the paid pack must cover the billed nodes.
-- false: only for the demo seed (SQL Editor).
create or replace function public.orchard_apply_design_for(p_user uuid, p_check boolean)
returns orchards
language plpgsql security definer set search_path = public as $$
declare
  o        orchards;
  d        jsonb;
  problem  text;
  q        record;
  z        jsonb;
  zid      uuid;
  prev     zones;
  kept     uuid[] := '{}';
  palette  text[] := array['#8BC34A', '#4FC3F7', '#FFB74D', '#BA68C8', '#4DB6AC', '#F06292',
                           '#AED581', '#7986CB', '#FFD54F', '#A1887F'];
  k        integer := 0;
  cx float8; cz float8;
  waiting  integer;
  me       profiles;
begin
  select * into o from orchards where farmer_id = p_user for update;
  if not found or o.design is null then
    raise exception 'No drawing to build' using errcode = 'PT409';
  end if;
  d := o.design;
  problem := public.orchard_design_problem(d, true);
  if problem is not null then
    raise exception 'Wrong drawing: %', problem using errcode = '22023';
  end if;
  if p_check then
    select * into q from public.orchard_quote_for(p_user);
    if q.kind <> 'covered' then
      -- PT402 = payment required (HTTP 402): pay first (new pack or extra nodes).
      raise exception 'Pay first: % nodes billed, % paid', q.billed_nodes, coalesce(q.paid_nodes, 0)
        using errcode = 'PT402';
    end if;
  end if;

  -- 1. The orchard.
  update orchards set
    name = coalesce(nullif(d ->> 'name', ''), name),
    draw_mode = d ->> 'mode',
    outline = d -> 'outline',
    origin_lat = case when d ->> 'mode' = 'map' then (d -> 'origin' ->> 'lat')::float8 end,
    origin_lng = case when d ->> 'mode' = 'map' then (d -> 'origin' ->> 'lng')::float8 end,
    tree_spacing_m = coalesce((d ->> 'spacing')::real, tree_spacing_m),
    status = 'complete',
    completed_at = coalesce(completed_at, now()),
    design = null
  where id = o.id
  returning * into o;

  -- 2. The zones: kept ones are changed, removed ones archived, new ones made.
  for z in select value from jsonb_array_elements(d -> 'zones') loop
    if z ->> 'id' is not null
       and exists (select 1 from zones where id = (z ->> 'id')::uuid and orchard_id = o.id and archived_at is null) then
      kept := kept || (z ->> 'id')::uuid;
    end if;
  end loop;
  for zid in
    update zones set archived_at = now()
    where orchard_id = o.id and archived_at is null and id <> all (kept)
    returning id
  loop
    -- Its trees: archived if they have history, removed otherwise.
    perform public.orchard_layout_zone(zid);
  end loop;
  -- Free the letters first (two zones may swap them).
  update zones set letter = null where orchard_id = o.id and archived_at is null;

  for z in select value from jsonb_array_elements(d -> 'zones') loop
    k := k + 1;
    select avg((e ->> 'x')::float8), avg((e ->> 'z')::float8) into cx, cz
    from jsonb_array_elements(z -> 'boundary') e;
    zid := case when (z ->> 'id')::uuid = any (kept) then (z ->> 'id')::uuid end;
    if zid is not null then
      select * into prev from zones where id = zid;
      update zones set
        letter = z ->> 'letter',
        name = coalesce(z ->> 'name', ''),
        zone_type = z ->> 'type',
        color = coalesce(z ->> 'color', palette[(k - 1) % 10 + 1]),
        boundary = z -> 'boundary',
        tree_count = (z ->> 'tree_count')::integer
      where id = zid;
      if prev.boundary is distinct from z -> 'boundary'
         or prev.tree_count is distinct from (z ->> 'tree_count')::integer then
        perform public.orchard_layout_zone(zid);
      end if;
    else
      insert into zones (orchard_id, letter, name, zone_type, color, boundary, tree_count)
      values (o.id, z ->> 'letter', coalesce(z ->> 'name', ''), z ->> 'type',
              coalesce(z ->> 'color', palette[(k - 1) % 10 + 1]),
              z -> 'boundary', (z ->> 'tree_count')::integer)
      returning id into zid;
      perform public.orchard_layout_zone(zid);
    end if;
    -- 3. One sensor node per zone (an installed box keeps its place).
    insert into nodes (zone_id, position_x, position_z, status)
    values (zid, round(cx::numeric, 2), round(cz::numeric, 2), 'offline')
    on conflict (zone_id) do update
      set position_x = excluded.position_x, position_z = excluded.position_z
      where nodes.installed_at is null;
  end loop;

  -- 4. Nodes waiting for the technician: one installation visit.
  select count(*) into waiting
  from nodes n join zones zn on zn.id = n.zone_id
  where zn.orchard_id = o.id and zn.archived_at is null and n.installed_at is null;
  if waiting > 0 then
    update kit_requests set orchard_id = o.id, nodes = waiting
    where user_id = p_user and status in ('new', 'contacted');
    if not found then
      select * into me from profiles where id = p_user;
      insert into kit_requests (user_id, orchard_id, phone, governorate, almond_trees, orchard_area_ha, nodes)
      values (p_user, o.id, me.phone, me.zone,
              (select sum(tree_count) from zones where orchard_id = o.id and archived_at is null),
              round(o.area::numeric, 2), waiting);
    end if;
  end if;
  return o;
end;
$$;

-- The app: builds the logged-in farmer's orchard (after the payment).
create or replace function public.orchard_apply_design() returns orchards
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  return public.orchard_apply_design_for(auth.uid(), true);
end;
$$;


-- ---------- 12) The rules (RLS) ----------
-- ORCHARDS: the farmer sees his own (his draft too, any pack); written only
-- by the functions above. Admins see all and may set confirmed_nodes.
drop policy if exists "Farmers manage their own orchards" on orchards;
drop policy if exists "Farmers see their own orchard" on orchards;
create policy "Farmers see their own orchard"
  on orchards for select to authenticated using (farmer_id = auth.uid());
drop policy if exists "Admins change orchards" on orchards;
create policy "Admins change orchards"
  on orchards for update to authenticated using (is_admin()) with check (is_admin());

-- ZONES / NODES / TREES: read with the paid pack; written by the functions.
drop policy if exists "Farmers manage zones in their orchards" on zones;
drop policy if exists "Farmers see the zones of their orchard" on zones;
create policy "Farmers see the zones of their orchard"
  on zones for select to authenticated using (owns_orchard(orchard_id) and has_plan('paid'));

drop policy if exists "Farmers manage nodes in their zones" on nodes;
drop policy if exists "Farmers see the nodes of their zones" on nodes;
create policy "Farmers see the nodes of their zones"
  on nodes for select to authenticated using (owns_zone(zone_id) and has_plan('paid'));

drop policy if exists "Farmers manage trees in their orchards" on trees;
drop policy if exists "Farmers see the trees of their orchard" on trees;
create policy "Farmers see the trees of their orchard"
  on trees for select to authenticated using (owns_orchard(orchard_id) and has_plan('paid'));

-- The other paid features (same rules as 004, with the new pack name).
drop policy if exists "Farmers manage their own plans" on orchard_plans;
create policy "Farmers manage their own plans"
  on orchard_plans for all to authenticated
  using (farmer_id = auth.uid() and has_plan('paid'))
  with check (farmer_id = auth.uid() and has_plan('paid'));

drop policy if exists "Farmers manage actions in their orchards" on field_actions;
create policy "Farmers manage actions in their orchards"
  on field_actions for all to authenticated
  using (owns_orchard(orchard_id) and has_plan('paid'))
  with check (owns_orchard(orchard_id) and has_plan('paid'));

drop policy if exists "Farmers see photos of their trees" on tree_photos;
create policy "Farmers see photos of their trees"
  on tree_photos for select to authenticated using (owns_tree(tree_id) and has_plan('paid'));
drop policy if exists "Farmers add photos of their trees" on tree_photos;
create policy "Farmers add photos of their trees"
  on tree_photos for insert to authenticated with check (owns_tree(tree_id) and has_plan('paid'));
drop policy if exists "Farmers delete photos of their trees" on tree_photos;
create policy "Farmers delete photos of their trees"
  on tree_photos for delete to authenticated using (owns_tree(tree_id) and has_plan('paid'));

drop policy if exists "Farmers see sensors in their orchards" on sensors;
create policy "Farmers see sensors in their orchards"
  on sensors for select to authenticated using (owns_node(node_id) and has_plan('paid'));

drop policy if exists "Farmers see advice for their trees and zones" on advice;
create policy "Farmers see advice for their trees and zones"
  on advice for select to authenticated
  using ((owns_tree(tree_id) or owns_zone(zone_id)) and has_plan('paid'));
drop policy if exists "Farmers accept or ignore advice" on advice;
create policy "Farmers accept or ignore advice"
  on advice for update to authenticated
  using ((owns_tree(tree_id) or owns_zone(zone_id)) and has_plan('paid'))
  with check ((owns_tree(tree_id) or owns_zone(zone_id)) and has_plan('paid'));

-- ALERTS: regional = everyone (unchanged rule), tree / zone = paid.
drop policy if exists "Farmers see alerts for their orchards" on alerts;
create policy "Farmers see alerts for their orchards"
  on alerts for select to authenticated
  using (((type = 'tree' and owns_tree(tree_id))
          or (type = 'zone' and (owns_zone(zone_id) or owns_sensor(sensor_id))))
         and has_plan('paid'));


-- ---------- 13) Who may call what ----------
revoke execute on function public.orchard_save_design(jsonb)  from public, anon;
revoke execute on function public.orchard_discard_design()     from public, anon;
revoke execute on function public.orchard_quote()              from public, anon;
revoke execute on function public.orchard_apply_design()       from public, anon;
revoke execute on function public.demo_payment(text, boolean)  from public, anon;
grant execute on function public.orchard_save_design(jsonb)    to authenticated;
grant execute on function public.orchard_discard_design()      to authenticated;
grant execute on function public.orchard_quote()               to authenticated;
grant execute on function public.orchard_apply_design()        to authenticated;
grant execute on function public.demo_payment(text, boolean)   to authenticated;

-- Server / SQL Editor only (never the app).
revoke execute on function public.orchard_quote_for(uuid)                       from public, anon, authenticated;
revoke execute on function public.orchard_apply_design_for(uuid, boolean)       from public, anon, authenticated;
revoke execute on function public.orchard_layout_zone(uuid)                     from public, anon, authenticated;
revoke execute on function public.activate_pack(uuid, text, integer, integer)   from public, anon, authenticated;
revoke execute on function public.set_pack_nodes(uuid, integer)                 from public, anon, authenticated;
revoke execute on function public.start_payment(uuid, text)                     from public, anon, authenticated;
revoke execute on function public.confirm_payment(text, integer)                from public, anon, authenticated;
grant execute on function public.orchard_quote_for(uuid)                        to service_role;
grant execute on function public.orchard_apply_design_for(uuid, boolean)        to service_role;
grant execute on function public.activate_pack(uuid, text, integer, integer)    to service_role;
grant execute on function public.set_pack_nodes(uuid, integer)                  to service_role;
grant execute on function public.start_payment(uuid, text)                      to service_role;
grant execute on function public.confirm_payment(text, integer)                 to service_role;


-- ---------- 14) Last check: you should see  paid=8000 | 2.00 | 0 | true | true ----------
select
  (select string_agg(plan || '=' || price_millimes, ',') from plan_prices)      as prices,
  (select hectares_per_node from app_settings where id)                         as hectares_per_node,
  (select count(*) from subscriptions where plan not in ('free', 'paid'))
    + (select count(*) from profiles where chosen_plan not in ('free', 'paid')) as old_packs_left,
  has_function_privilege('authenticated', 'public.orchard_apply_design()', 'execute')
    and not has_function_privilege('authenticated', 'public.activate_pack(uuid, text, integer, integer)', 'execute')
    and not has_function_privilege('authenticated', 'public.orchard_apply_design_for(uuid, boolean)', 'execute')
                                                                                as app_rights_ok,
  (select bool_and(relrowsecurity) from pg_class
   where relname in ('orchards', 'zones', 'nodes', 'trees', 'kit_requests', 'subscriptions')
     and relnamespace = 'public'::regnamespace)                                 as rules_on;
