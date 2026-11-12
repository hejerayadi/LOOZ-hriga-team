-- =========================================================
-- LOOZ — the IoT DEMO FARMER (seed, NOT a migration)
--
-- Gives the account +216 22 777 001 ("Demo IoT", Sfax) the orchard of the
-- Node-RED simulation (flow "Almond Smart Farm", orchard VERGER-NORD),
-- exactly:
--
--   Node-RED zone | here   | box (device code) | cultivar, age     | trees
--   1             | zone A | NODE-01           | Nonpareil, 8 y    | TREE-012 013 014 027 028
--   2             | zone B | NODE-02           | Nonpareil, 10 y   | TREE-042 043 044 058
--   3             | zone C | NODE-03           | Tuono, 12 y       | TREE-073 074 075 076 077
--   4             | zone D | NODE-04           | Ferraduel, 4 y    | TREE-089 090 091 092
--
--   - a small outline (56 m x 21 m, 0.12 ha) cut in 4 strips, west to
--     east; the trees in rows 7 m apart, the box in the middle of its zone;
--   - the 4 boxes ACCEPTED (installed) by an admin, the installation visit
--     done (to leave a box waiting, e.g. to test the "Accepter" button of
--     the dashboard: put its code in waiting_nodes below);
--   - the paid pack with 4 boxes for 90 days (no payment row: it is a
--     demo). A pack still running keeps its end date;
--   - the gateway GW-01 of the farm, in DEMO time (the simulated clock of
--     Node-RED), one history point per box per simulated hour.
--
-- BEFORE: make the account in the app (demo login): "إنشاء حساب",
--   22 777 001, any 6 digits, "فلاح", any name, Sfax, the free pack.
--   (If the app says "هذا الرقم لديه حساب بالفعل", the number is used.)
-- AFTER: the last line shows the gateway KEY: paste it in
--   iot/node-red/.env (LOOZ_GATEWAY_KEY=...). EVERY run makes a NEW key
--   (the old one stops working) and a fresh orchard (no readings).
--
-- Remove it: supabase/seed/iot_demo_farmer_delete.sql (the pack stays).
-- The demo orchard of +216 22 123 456 is never touched.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Needs migrations 011 and 012. ONE statement (do $$ ... $$) + a check.
-- =========================================================

do $$
declare
  demo_phone    constant text    := '+21622777001';
  demo_first    constant text    := 'Demo';
  demo_last     constant text    := 'IoT';
  pack_days     constant integer := 90;
  waiting_nodes constant text[]  := '{}';   -- e.g. '{NODE-04}': left "waiting for installation"
  me            profiles;
  sub           subscriptions;
  oid           uuid;
begin
  select * into me from profiles where phone = demo_phone;
  if me.id is null then
    raise exception 'No account with the number % yet: make it in the app first (demo login), then run this file again.', demo_phone;
  end if;
  if me.role is distinct from 'farmer' then
    raise exception 'The account % is not a farmer (role %): nothing was changed.', demo_phone, me.role;
  end if;
  if exists (select 1 from orchards where farmer_id = me.id and not is_demo) then
    raise exception 'The account % already has its own orchard: nothing was changed.', demo_phone;
  end if;
  if exists (select 1 from gateways g join orchards o on o.id = g.orchard_id
             where g.code = 'GW-01' and o.farmer_id <> me.id) then
    raise exception 'The gateway code GW-01 belongs to another orchard: nothing was changed.';
  end if;
  if exists (select 1 from nodes n join zones z on z.id = n.zone_id join orchards o on o.id = z.orchard_id
             where n.hardware_id in ('NODE-01', 'NODE-02', 'NODE-03', 'NODE-04') and o.farmer_id <> me.id) then
    raise exception 'A device code NODE-01..04 is used by another orchard: nothing was changed.';
  end if;

  -- The person: a simple demo name, governorate Sfax.
  update profiles set first_name = demo_first, last_name = demo_last, zone = 'sfax' where id = me.id;

  -- Run again: the old demo orchard goes first (its boxes, readings and gateway with it).
  delete from kit_requests where orchard_id in (select id from orchards where farmer_id = me.id and is_demo);
  delete from orchards where farmer_id = me.id and is_demo;

  -- The drawing (what the designer saves): x = east, z = south, in metres.
  insert into orchards (farmer_id, name, is_demo, design)
  values (me.id, '', true, '{"step": "review", "mode": "grid", "name": "", "spacing": 7, "zone_method": "auto",
    "outline": [{"x": -28, "z": -10.5}, {"x": 28, "z": -10.5}, {"x": 28, "z": 10.5}, {"x": -28, "z": 10.5}],
    "zones": [
      {"letter": "A", "name": "", "type": "irrigated", "color": "#8BC34A", "tree_count": 5,
       "boundary": [{"x": -28, "z": -10.5}, {"x": -14, "z": -10.5}, {"x": -14, "z": 10.5}, {"x": -28, "z": 10.5}]},
      {"letter": "B", "name": "", "type": "irrigated", "color": "#4FC3F7", "tree_count": 4,
       "boundary": [{"x": -14, "z": -10.5}, {"x": 0, "z": -10.5}, {"x": 0, "z": 10.5}, {"x": -14, "z": 10.5}]},
      {"letter": "C", "name": "", "type": "old_trees", "color": "#FFB74D", "tree_count": 5,
       "boundary": [{"x": 0, "z": -10.5}, {"x": 14, "z": -10.5}, {"x": 14, "z": 10.5}, {"x": 0, "z": 10.5}]},
      {"letter": "D", "name": "", "type": "young_trees", "color": "#BA68C8", "tree_count": 4,
       "boundary": [{"x": 14, "z": -10.5}, {"x": 28, "z": -10.5}, {"x": 28, "z": 10.5}, {"x": 14, "z": 10.5}]}
    ]}'::jsonb)
  returning id into oid;

  -- The paid pack (4 boxes), then the build (zones, one box per zone, visit).
  select * into sub from subscriptions
  where user_id = me.id and plan = 'paid' and status = 'active' and (ends_at is null or ends_at > now());
  if sub.user_id is null then
    perform public.activate_pack(me.id, 'paid', pack_days, 4);
  elsif sub.nodes is not null and sub.nodes < 4 then
    perform public.set_pack_nodes(me.id, 4);
  end if;
  perform public.orchard_apply_design_for(me.id, true);

  -- Cultivar and age of each zone (age in 2026 -> planting year).
  update zones z set cultivar = v.cultivar, planted_year = v.planted
  from (values ('A', 'Nonpareil', 2018), ('B', 'Nonpareil', 2016),
               ('C', 'Tuono', 2014), ('D', 'Ferraduel', 2022)) as v(letter, cultivar, planted)
  where z.orchard_id = oid and z.archived_at is null and z.letter = v.letter;

  -- The 18 trees of Node-RED, in place of the trees made by the build:
  -- rows 7 m apart (north row z = -7, middle z = 0, south z = 7).
  delete from trees where orchard_id = oid;
  insert into trees (orchard_id, zone_id, code, variety, pos_x, pos_z)
  select oid, z.id, t.code, z.cultivar, t.x, t.z
  from (values
    ('A', 'TREE-012', -24.5, -7), ('A', 'TREE-013', -17.5, -7), ('A', 'TREE-014', -24.5, 0),
    ('A', 'TREE-027', -24.5, 7),  ('A', 'TREE-028', -17.5, 7),
    ('B', 'TREE-042', -10.5, -7), ('B', 'TREE-043', -3.5, -7),
    ('B', 'TREE-044', -10.5, 7),  ('B', 'TREE-058', -3.5, 7),
    ('C', 'TREE-073', 3.5, -7),   ('C', 'TREE-074', 10.5, -7), ('C', 'TREE-075', 3.5, 0),
    ('C', 'TREE-076', 3.5, 7),    ('C', 'TREE-077', 10.5, 7),
    ('D', 'TREE-089', 17.5, -7),  ('D', 'TREE-090', 24.5, -7),
    ('D', 'TREE-091', 17.5, 7),   ('D', 'TREE-092', 24.5, 7)) as t(letter, code, x, z)
  join zones z on z.orchard_id = oid and z.archived_at is null and z.letter = t.letter;

  -- The boxes: device codes NODE-01..04 (zone A..D), in the middle of their zone.
  update nodes n set hardware_id = 'NODE-0' || (ascii(z.letter) - 64)::text,
                     position_x = case z.letter when 'A' then -21 when 'B' then -7 when 'C' then 7 else 21 end,
                     position_z = 0
  from zones z
  where z.id = n.zone_id and z.orchard_id = oid and z.archived_at is null;

  -- Accepted by an admin (the visit is done), except waiting_nodes.
  if cardinality(waiting_nodes) = 0 then
    update kit_requests set status = 'installed', admin_note = 'Agriculteur de démonstration IoT (seed)' where orchard_id = oid;
  else
    update nodes n set installed_at = now()
    from zones z
    where z.id = n.zone_id and z.orchard_id = oid and z.archived_at is null
      and n.hardware_id <> all (waiting_nodes);
    update kit_requests set admin_note = 'Agriculteur de démonstration IoT (seed)' where orchard_id = oid;
  end if;

  -- The gateway of the farm (Node-RED). Its key is made by the check below.
  insert into gateways (code, orchard_id, time_mode, history_minutes, offline_after_minutes)
  values ('GW-01', oid, 'demo', 60, 5);
end $$;

-- Check: you should see
--   +21622777001 | Demo IoT | sfax | 0.1176 | 4 | NODE-01,NODE-02,NODE-03,NODE-04 | 4
--   | A:5 B:4 C:5 D:4 | 18 | paid | 4 | GW-01 demo | lgw_... (the KEY: copy it now)
select p.phone,
       p.name,
       p.zone                                                                    as governorate,
       o.area                                                                    as hectares,
       (select count(*) from zones z where z.orchard_id = o.id and z.archived_at is null) as zones,
       (select string_agg(n.hardware_id, ',' order by n.hardware_id)
          from nodes n join zones z on z.id = n.zone_id where z.orchard_id = o.id) as device_codes,
       (select count(*) from nodes n join zones z on z.id = n.zone_id
         where z.orchard_id = o.id and n.installed_at is not null)              as accepted_boxes,
       (select string_agg(z.letter || ':' || (select count(*) from trees t where t.zone_id = z.id), ' '
                          order by z.letter)
          from zones z where z.orchard_id = o.id and z.archived_at is null)     as trees_per_zone,
       (select count(*) from trees t where t.orchard_id = o.id)                 as trees,
       s.plan,
       s.nodes                                                                   as paid_boxes,
       g.code || ' ' || g.time_mode                                              as gateway,
       public.iot_gateway_new_key(g.code)                                        as gateway_key
from orchards o
join profiles p on p.id = o.farmer_id
join subscriptions s on s.user_id = o.farmer_id
join gateways g on g.orchard_id = o.id
where o.is_demo and p.phone = '+21622777001';
