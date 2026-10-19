-- =========================================================
-- LOOZ — Migration 002: zones and sensor nodes
--
-- The orchard is now split into ZONES (areas with the same kind of soil),
-- with ONE sensor node per zone. Sensors hang on the node, not on a tree
-- (except sensors really attached to one tree, like a leaf sensor).
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER looz_schema.sql and looz_policies.sql.
-- Safe to run again. If you re-run looz_policies.sql later, run this file
-- again afterwards (it updates some of the policies created there).
-- =========================================================

-- All or nothing: if one line fails, nothing is changed.
begin;


-- ---------- 1) ZONES ----------
create table if not exists zones (
  id          uuid primary key default gen_random_uuid(),
  orchard_id  uuid not null references orchards(id) on delete cascade,  -- Orchard 1 ◆ 0..* Zone
  name        text not null,                                         -- e.g. 'Zone A'
  -- Corners of the zone in the 3D scene (meters), e.g. [{"x": -24, "z": -18}, ...]
  boundary    jsonb not null default '[]'::jsonb check (jsonb_typeof(boundary) = 'array'),
  soil_notes  text,
  health      text not null default 'good' check (health in ('good', 'warning', 'danger')),
  created_at  timestamptz default now()
);

create index if not exists zones_orchard_id_idx on zones(orchard_id);


-- ---------- 2) NODES (one sensor box per zone) ----------
create table if not exists nodes (
  id          uuid primary key default gen_random_uuid(),
  zone_id     uuid not null unique references zones(id) on delete cascade,  -- Zone 1 has 0..1 Node
  position_x  real,          -- position in the 3D orchard (meters)
  position_z  real,
  battery     integer,
  last_seen   timestamptz,
  status      text not null default 'offline' check (status in ('online', 'offline'))
);


-- ---------- 3) TREES: each tree can belong to a zone ----------
alter table trees add column if not exists zone_id uuid references zones(id) on delete set null;

create index if not exists trees_zone_id_idx on trees(zone_id);


-- ---------- 4) SENSORS: hang on a node (or, for a leaf sensor, on a tree) ----------
alter table sensors add column if not exists node_id uuid references nodes(id) on delete cascade;
alter table sensors alter column tree_id drop not null;

-- A sensor must be on a node, on a tree, or both.
alter table sensors drop constraint if exists sensors_node_or_tree_check;
alter table sensors add constraint sensors_node_or_tree_check
  check (node_id is not null or tree_id is not null);

create index if not exists sensors_node_id_idx on sensors(node_id);

-- Move the soil and air sensors to the node of their tree's zone.
-- Only possible for trees that already have a zone (and a zone that has a node).
-- The others stay as they are. Leaf sensors stay on their tree.
update sensors s
set node_id = n.id
from trees t
join nodes n on n.zone_id = t.zone_id
where s.tree_id = t.id
  and s.node_id is null
  and s.type in ('soil', 'air');


-- ---------- 5) ALERTS: can point to a zone ----------
-- The old text column "zone" stays, for regional alerts (e.g. 'Sfax').
alter table alerts add column if not exists zone_id uuid references zones(id) on delete set null;

-- New alert type 'zone' (an alert about one zone of an orchard).
alter table alerts drop constraint if exists alerts_type_check;
alter table alerts add constraint alerts_type_check
  check (type in ('regional', 'tree', 'zone'));

create index if not exists alerts_zone_id_idx on alerts(zone_id);


-- ---------- 6) ADVICE: for a whole zone, or for one tree ----------
-- "on delete cascade": advice about a zone is deleted with its zone.
-- (With "set null", deleting a zone or an orchard would break the check below.)
alter table advice add column if not exists zone_id uuid references zones(id) on delete cascade;
alter table advice alter column tree_id drop not null;

-- At least one of them must be set.
alter table advice drop constraint if exists advice_zone_or_tree_check;
alter table advice add constraint advice_zone_or_tree_check
  check (zone_id is not null or tree_id is not null);

create index if not exists advice_zone_id_idx on advice(zone_id);


-- ---------- 7) Helper functions (same style as owns_orchard / owns_tree) ----------

-- Does the logged-in user own this zone (through its orchard)?
create or replace function public.owns_zone(z_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from zones where id = z_id and owns_orchard(orchard_id));
$$;

-- Does the logged-in user own this node (through its zone)?
create or replace function public.owns_node(n_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from nodes where id = n_id and owns_zone(zone_id));
$$;

-- Does the logged-in user own this sensor (through its tree or its node)?
create or replace function public.owns_sensor(s_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from sensors
    where id = s_id and (owns_tree(tree_id) or owns_node(node_id))
  );
$$;

-- Is this zone part of this orchard? (a tree can only join a zone of its own orchard)
create or replace function public.zone_in_orchard(z_id uuid, o_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from zones where id = z_id and orchard_id = o_id);
$$;


-- ---------- 8) Security rules (RLS) ----------
alter table zones enable row level security;
alter table nodes enable row level security;

-- ZONES: farmers manage the zones of their orchards, admins see all.
drop policy if exists "Farmers manage zones in their orchards" on zones;
create policy "Farmers manage zones in their orchards"
  on zones for all to authenticated
  using (owns_orchard(orchard_id)) with check (owns_orchard(orchard_id));

drop policy if exists "Admins see all zones" on zones;
create policy "Admins see all zones"
  on zones for select to authenticated using (is_admin());

-- NODES: farmers manage the nodes of their zones, admins manage all
-- (like sensors: admins install the hardware).
drop policy if exists "Farmers manage nodes in their zones" on nodes;
create policy "Farmers manage nodes in their zones"
  on nodes for all to authenticated
  using (owns_zone(zone_id)) with check (owns_zone(zone_id));

drop policy if exists "Admins manage nodes" on nodes;
create policy "Admins manage nodes"
  on nodes for all to authenticated using (is_admin()) with check (is_admin());

-- TREES: same rule as before, plus: the zone must be in the tree's orchard.
drop policy if exists "Farmers manage trees in their orchards" on trees;
create policy "Farmers manage trees in their orchards"
  on trees for all to authenticated
  using (owns_orchard(orchard_id))
  with check (owns_orchard(orchard_id) and (zone_id is null or zone_in_orchard(zone_id, orchard_id)));

-- SENSORS: farmers see the sensors on their trees OR on their nodes.
-- (Admins still manage sensors: policy "Admins manage sensors" is unchanged.)
drop policy if exists "Farmers see sensors on their trees" on sensors;
drop policy if exists "Farmers see sensors in their orchards" on sensors;
create policy "Farmers see sensors in their orchards"
  on sensors for select to authenticated
  using (owns_tree(tree_id) or owns_node(node_id));

-- ALERTS: farmers see tree/zone alerts from their own sensors or zones.
-- (Regional alerts: policy "Everyone logged in sees regional alerts" is unchanged.)
drop policy if exists "Farmers see alerts from their own sensors" on alerts;
drop policy if exists "Farmers see alerts for their orchards" on alerts;
create policy "Farmers see alerts for their orchards"
  on alerts for select to authenticated
  using (type in ('tree', 'zone') and (owns_sensor(sensor_id) or owns_zone(zone_id)));

-- ADVICE: farmers see and answer advice for their trees OR their zones.
drop policy if exists "Farmers see advice for their trees" on advice;
drop policy if exists "Farmers see advice for their trees and zones" on advice;
create policy "Farmers see advice for their trees and zones"
  on advice for select to authenticated
  using (owns_tree(tree_id) or owns_zone(zone_id));

drop policy if exists "Farmers accept or ignore advice" on advice;
create policy "Farmers accept or ignore advice"
  on advice for update to authenticated
  using (owns_tree(tree_id) or owns_zone(zone_id))
  with check (owns_tree(tree_id) or owns_zone(zone_id));


commit;
