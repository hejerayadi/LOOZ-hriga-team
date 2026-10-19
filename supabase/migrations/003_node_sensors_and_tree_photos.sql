-- =========================================================
-- LOOZ — Migration 003: sensors only on nodes + tree photos
--
-- - We have NO sensor data per tree: every sensor belongs to a zone's node.
-- - A tree's health = its zone's health (zones.health). The tree's own
--   "health" column is removed.
-- - The ONLY tree-level information is a photo diagnosis (table tree_photos).
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 002. Safe to run again.
-- (Do not re-run 002 after this file: 002 still talks about sensors.tree_id.)
--
-- ⚠ Deletes data: sensors that are not on a node (e.g. leaf sensors) are
--   deleted, and the trees.health values are dropped.
-- =========================================================

-- All or nothing: if one line fails, nothing is changed.
begin;


-- ---------- 1) SENSORS: only on nodes ----------
-- Remove the rules that still use sensors.tree_id (recreated below without it).
drop policy if exists "Farmers see sensors on their trees" on sensors;
drop policy if exists "Farmers see sensors in their orchards" on sensors;
alter table sensors drop constraint if exists sensors_node_or_tree_check;

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'sensors' and column_name = 'tree_id') then
    -- Last chance to keep soil/air sensors: move them to their zone's node.
    update sensors s
    set node_id = n.id
    from trees t
    join nodes n on n.zone_id = t.zone_id
    where s.tree_id = t.id and s.node_id is null and s.type in ('soil', 'air');

    alter table sensors drop column tree_id;
  end if;
end $$;

-- Sensors that are still not on a node (leaf sensors...) are deleted.
delete from sensors where node_id is null;
alter table sensors alter column node_id set not null;

-- No more leaf sensors.
alter table sensors drop constraint if exists sensors_type_check;
alter table sensors add constraint sensors_type_check check (type in ('soil', 'air'));

-- Owner of a sensor = owner of its node (no tree anymore).
create or replace function public.owns_sensor(s_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from sensors where id = s_id and owns_node(node_id));
$$;

create policy "Farmers see sensors in their orchards"
  on sensors for select to authenticated
  using (owns_node(node_id));


-- ---------- 2) TREES: no separate health value ----------
-- A tree's health is its zone's health (zones.health),
-- or its latest photo diagnosis (tree_photos below).
alter table trees drop column if exists health;


-- ---------- 3) TREE PHOTOS: the only tree-level information ----------
create table if not exists tree_photos (
  id          uuid primary key default gen_random_uuid(),
  tree_id     uuid not null references trees(id) on delete cascade,  -- Tree 1 ◆ 0..* TreePhoto
  image_path  text not null,     -- path of the image in Supabase Storage
  ai_result   jsonb,             -- what the AI found, e.g. {"label": "tavelure", "confidence": 0.82}
  status      text not null check (status in ('good', 'warning', 'danger')),
  created_at  timestamptz default now()
);

-- Fast "latest photo of each tree".
create index if not exists tree_photos_tree_id_created_at_idx on tree_photos(tree_id, created_at desc);

-- The latest photo of each tree. "security_invoker": the rules (RLS) of the
-- person asking still apply, so a farmer only sees his own trees here.
create or replace view tree_latest_photos with (security_invoker = true) as
  select distinct on (tree_id) *
  from tree_photos
  order by tree_id, created_at desc;

alter table tree_photos enable row level security;

-- Farmers see, add and delete the photos of their own trees.
-- (The AI result can also be written by the AI service, which bypasses RLS.)
drop policy if exists "Farmers see photos of their trees" on tree_photos;
create policy "Farmers see photos of their trees"
  on tree_photos for select to authenticated using (owns_tree(tree_id));

drop policy if exists "Farmers add photos of their trees" on tree_photos;
create policy "Farmers add photos of their trees"
  on tree_photos for insert to authenticated with check (owns_tree(tree_id));

drop policy if exists "Farmers delete photos of their trees" on tree_photos;
create policy "Farmers delete photos of their trees"
  on tree_photos for delete to authenticated using (owns_tree(tree_id));

drop policy if exists "Admins see all photos" on tree_photos;
create policy "Admins see all photos"
  on tree_photos for select to authenticated using (is_admin());


commit;
