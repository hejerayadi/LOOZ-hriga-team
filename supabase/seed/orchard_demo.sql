-- =========================================================
-- LOOZ — DEMO orchard (seed, NOT a migration)
--
-- Gives the demo account +216 22 123 456 a ready orchard, as if the farmer
-- had drawn it in the designer and paid:
--   - outline of 2.37 ha (drawn on the grid), 4 zones made automatically
--     from the number of trees: A young trees (160), B old trees (210),
--     C sandy soil (120), D rain-fed (190);
--   - one sensor node per zone, already "installed" and sending (demo);
--   - the trees in rows inside each zone (about 680);
--   - the paid pack with 4 nodes (no payment row: it is a demo). A pack
--     still running keeps its end date.
--
-- Another account: change demo_phone below (the account must exist: make
-- it in the app first). Run it again = a fresh demo orchard. An account
-- with its OWN orchard is never touched.
-- Remove it: supabase/seed/orchard_demo_delete.sql (the pack stays).
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Needs migration 011. ONE statement (do $$ ... $$) + a check.
-- =========================================================

do $$
declare
  demo_phone constant text := '+21622123456';
  uid        uuid;
  sub        subscriptions;
  oid        uuid;
begin
  select id into uid from profiles where phone = demo_phone;
  if uid is null then
    raise exception 'No account with the number % (make it in the app first, or change demo_phone)', demo_phone;
  end if;
  if exists (select 1 from orchards where farmer_id = uid and not is_demo) then
    raise exception 'The account % already has its own orchard: nothing was changed.', demo_phone;
  end if;

  -- Run again: the old demo orchard goes first.
  delete from kit_requests where orchard_id in (select id from orchards where farmer_id = uid and is_demo);
  delete from orchards where farmer_id = uid and is_demo;

  -- The drawing (what the designer saves), then the pack, then the build.
  insert into orchards (farmer_id, name, is_demo, design)
  values (uid, '', true, '{"step": "review", "mode": "grid", "name": "", "spacing": 7, "zone_method": "auto",
    "outline": [{"x": -90, "z": -60}, {"x": 85, "z": -70}, {"x": 100, "z": 40}, {"x": 20, "z": 75}, {"x": -95, "z": 55}],
    "zones": [
      {"letter": "A", "name": "", "type": "young_trees", "color": "#8BC34A", "tree_count": 160,
       "boundary": [{"x": -90, "z": -60}, {"x": -46.3, "z": -62.5}, {"x": -46.3, "z": 63.5}, {"x": -95, "z": 55}]},
      {"letter": "B", "name": "", "type": "old_trees", "color": "#4FC3F7", "tree_count": 210,
       "boundary": [{"x": -46.3, "z": -62.5}, {"x": 9.0, "z": -65.7}, {"x": 9.0, "z": 73.1}, {"x": -46.3, "z": 63.5}]},
      {"letter": "C", "name": "", "type": "sandy_soil", "color": "#FFB74D", "tree_count": 120,
       "boundary": [{"x": 9.0, "z": -65.7}, {"x": 39.1, "z": -67.4}, {"x": 39.1, "z": 66.6}, {"x": 20, "z": 75}, {"x": 9.0, "z": 73.1}]},
      {"letter": "D", "name": "", "type": "rainfed", "color": "#BA68C8", "tree_count": 190,
       "boundary": [{"x": 39.1, "z": -67.4}, {"x": 85, "z": -70}, {"x": 100, "z": 40}, {"x": 39.1, "z": 66.6}]}
    ]}'::jsonb)
  returning id into oid;

  select * into sub from subscriptions
  where user_id = uid and plan = 'paid' and status = 'active' and (ends_at is null or ends_at > now());
  if sub.user_id is null then
    perform public.activate_pack(uid, 'paid', 30, 4);
  elsif sub.nodes is not null and sub.nodes < 4 then
    perform public.set_pack_nodes(uid, 4);
  end if;
  perform public.orchard_apply_design_for(uid, true);

  -- Demo: the 4 boxes are installed and send data (zone C's box is offline).
  update kit_requests set status = 'installed', admin_note = 'Demo orchard (seed)' where orchard_id = oid;
  update zones set health = case letter when 'B' then 'warning' when 'C' then 'danger' else 'good' end
  where orchard_id = oid and archived_at is null;
  update nodes n set
    status = case z.letter when 'C' then 'offline' else 'online' end,
    battery = case z.letter when 'A' then 82 when 'B' then 18 when 'C' then 6 else 64 end,
    last_seen = now() - case z.letter when 'C' then interval '3 hours' else interval '5 minutes' end,
    hardware_id = 'DEMO-' || z.letter
  from zones z where z.id = n.zone_id and z.orchard_id = oid and z.archived_at is null;
end $$;

-- Check: you should see  +21622123456 | 2.3688 | 4 | 4 | about 670 | paid | 4
select p.phone,
       o.area                                                        as hectares,
       (select count(*) from zones z where z.orchard_id = o.id and z.archived_at is null) as zones,
       (select count(*) from nodes n join zones z on z.id = n.zone_id
        where z.orchard_id = o.id and n.installed_at is not null)    as installed_nodes,
       (select count(*) from trees t where t.orchard_id = o.id and t.archived_at is null) as trees,
       s.plan,
       s.nodes                                                       as paid_nodes
from orchards o
join profiles p on p.id = o.farmer_id
join subscriptions s on s.user_id = o.farmer_id
where o.is_demo;
