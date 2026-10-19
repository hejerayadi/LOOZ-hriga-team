-- =========================================================
-- LOOZ — Migration 004: subscription plans
--
-- Plans (from small to big):
--   free       (Gratuit)   community, AI assistant (10 questions/day), regional alerts
--   essential  (Essentiel) + land/soil setup, plot/tree/zone drawing, 3D map,
--                            AI tree layout, photo diagnosis
--   connected  (Connecté)  + IoT nodes and live zone data, zone alerts,
--                            AI predictions (irrigation, harvest)
--
-- The database itself enforces the plans (RLS). Only admins change a plan.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 003. Safe to run again.
-- ⚠ If you ever re-run looz_policies.sql, 002 or 003, run THIS file again
--   afterwards: they recreate some rules WITHOUT the plan checks.
-- =========================================================

-- All or nothing: if one line fails, nothing is changed.
begin;


-- ---------- 0) Tree alerts and tree advice come ONLY from photo diagnoses ----------
-- A tree alert must point to its tree (so its owner can see it), never to a sensor.
alter table alerts add column if not exists tree_id uuid references trees(id) on delete cascade;
create index if not exists alerts_tree_id_idx on alerts(tree_id);

-- "not valid": checked for new alerts only (old tree alerts are left as they are).
alter table alerts drop constraint if exists alerts_tree_from_photo_check;
alter table alerts add constraint alerts_tree_from_photo_check
  check (type <> 'tree' or (sensor_id is null and tree_id is not null)) not valid;

comment on column alerts.type is
  'regional = sent by an admin; zone = from the zone''s node sensors; '
  'tree = ONLY from a photo diagnosis (tree_photos), never from sensors.';
comment on column alerts.tree_id is
  'Tree alerts only: the tree whose photo diagnosis raised the alert.';
comment on column advice.tree_id is
  'Tree advice comes ONLY from a photo diagnosis (tree_photos), never from sensors. '
  'Zone advice (zone_id) can come from the node sensors.';


-- ---------- 1) SUBSCRIPTIONS: one row per user ----------
-- Created by looz_schema.sql with other columns (farmer_id, start_date, end_date,
-- status active/paused/ended): renamed here to the new shape.
create table if not exists subscriptions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null unique references profiles(id) on delete cascade,
  plan        text not null default 'free',
  status      text not null default 'active',
  started_at  timestamptz not null default now(),
  ends_at     timestamptz
);

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'subscriptions' and column_name = 'farmer_id') then
    alter table subscriptions rename column farmer_id to user_id;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'subscriptions' and column_name = 'start_date') then
    alter table subscriptions rename column start_date to started_at;
    alter table subscriptions alter column started_at type timestamptz using started_at::timestamptz;
    alter table subscriptions alter column started_at set default now();
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'subscriptions' and column_name = 'end_date') then
    alter table subscriptions rename column end_date to ends_at;
    alter table subscriptions alter column ends_at type timestamptz using ends_at::timestamptz;
  end if;
end $$;

alter table subscriptions add column if not exists plan text not null default 'free';

-- Old statuses 'paused' / 'ended' become 'expired'.
alter table subscriptions drop constraint if exists subscriptions_status_check;
update subscriptions set status = 'expired' where status not in ('active', 'expired');
alter table subscriptions add constraint subscriptions_status_check
  check (status in ('active', 'expired'));

alter table subscriptions drop constraint if exists subscriptions_plan_check;
alter table subscriptions add constraint subscriptions_plan_check
  check (plan in ('free', 'essential', 'connected'));


-- ---------- 2) Every new user gets 'free' automatically ----------
create or replace function public.create_free_subscription() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into subscriptions (user_id, plan, status) values (new.id, 'free', 'active')
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_profile_created on profiles;
create trigger on_profile_created
  after insert on profiles
  for each row execute function public.create_free_subscription();

-- Users who already exist and have no subscription yet: 'free' too.
insert into subscriptions (user_id, plan, status)
select id, 'free', 'active' from profiles
where id not in (select user_id from subscriptions)
on conflict (user_id) do nothing;


-- ---------- 3) Helper functions ----------

-- Rank of a plan: free 0 < essential 1 < connected 2 (null = unknown name).
create or replace function public.plan_rank(p text) returns integer
language sql immutable as $$
  select case p when 'free' then 0 when 'essential' then 1 when 'connected' then 2 end;
$$;

-- Plan of the logged-in user. No active subscription (or it ended) = 'free'.
create or replace function public.user_plan() returns text
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select plan from subscriptions
     where user_id = auth.uid()
       and status = 'active'
       and (ends_at is null or ends_at > now())),
    'free');
$$;

-- Does the logged-in user have at least this plan?
-- A misspelled plan name never gives access (unknown = 99).
create or replace function public.has_plan(min_plan text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(plan_rank(user_plan()), 0) >= coalesce(plan_rank(min_plan), 99);
$$;


-- ---------- 4) SUBSCRIPTIONS rules: users read theirs, only admins change ----------
drop policy if exists "Farmers see their own subscription" on subscriptions;
drop policy if exists "Farmers create their own subscription" on subscriptions;
drop policy if exists "Users see their own subscription" on subscriptions;
create policy "Users see their own subscription"
  on subscriptions for select to authenticated using (user_id = auth.uid());

drop policy if exists "Admins manage subscriptions" on subscriptions;
create policy "Admins manage subscriptions"
  on subscriptions for all to authenticated using (is_admin()) with check (is_admin());

alter table subscriptions enable row level security;


-- ---------- 5) ESSENTIAL: land, plot, trees, zones, 3D, photos ----------
-- (Same rules as before + has_plan(...). Admin rules are unchanged.)
drop policy if exists "Farmers manage their own orchards" on orchards;
create policy "Farmers manage their own orchards"
  on orchards for all to authenticated
  using (farmer_id = auth.uid() and has_plan('essential'))
  with check (farmer_id = auth.uid() and has_plan('essential'));

drop policy if exists "Farmers manage their own plans" on orchard_plans;
create policy "Farmers manage their own plans"
  on orchard_plans for all to authenticated
  using (farmer_id = auth.uid() and has_plan('essential'))
  with check (farmer_id = auth.uid() and has_plan('essential'));

drop policy if exists "Farmers manage trees in their orchards" on trees;
create policy "Farmers manage trees in their orchards"
  on trees for all to authenticated
  using (owns_orchard(orchard_id) and has_plan('essential'))
  with check (owns_orchard(orchard_id) and has_plan('essential')
              and (zone_id is null or zone_in_orchard(zone_id, orchard_id)));

drop policy if exists "Farmers manage zones in their orchards" on zones;
create policy "Farmers manage zones in their orchards"
  on zones for all to authenticated
  using (owns_orchard(orchard_id) and has_plan('essential'))
  with check (owns_orchard(orchard_id) and has_plan('essential'));

drop policy if exists "Farmers manage actions in their orchards" on field_actions;
create policy "Farmers manage actions in their orchards"
  on field_actions for all to authenticated
  using (owns_orchard(orchard_id) and has_plan('essential'))
  with check (owns_orchard(orchard_id) and has_plan('essential'));

drop policy if exists "Farmers see photos of their trees" on tree_photos;
create policy "Farmers see photos of their trees"
  on tree_photos for select to authenticated
  using (owns_tree(tree_id) and has_plan('essential'));

drop policy if exists "Farmers add photos of their trees" on tree_photos;
create policy "Farmers add photos of their trees"
  on tree_photos for insert to authenticated
  with check (owns_tree(tree_id) and has_plan('essential'));

drop policy if exists "Farmers delete photos of their trees" on tree_photos;
create policy "Farmers delete photos of their trees"
  on tree_photos for delete to authenticated
  using (owns_tree(tree_id) and has_plan('essential'));


-- ---------- 6) CONNECTED: nodes, sensors, zone data ----------
drop policy if exists "Farmers manage nodes in their zones" on nodes;
create policy "Farmers manage nodes in their zones"
  on nodes for all to authenticated
  using (owns_zone(zone_id) and has_plan('connected'))
  with check (owns_zone(zone_id) and has_plan('connected'));

drop policy if exists "Farmers see sensors in their orchards" on sensors;
create policy "Farmers see sensors in their orchards"
  on sensors for select to authenticated
  using (owns_node(node_id) and has_plan('connected'));


-- ---------- 7) ADVICE: tree advice (photo) = essential, zone advice (sensors / AI predictions) = connected ----------
drop policy if exists "Farmers see advice for their trees and zones" on advice;
create policy "Farmers see advice for their trees and zones"
  on advice for select to authenticated
  using ((owns_tree(tree_id) and has_plan('essential'))
         or (owns_zone(zone_id) and has_plan('connected')));

drop policy if exists "Farmers accept or ignore advice" on advice;
create policy "Farmers accept or ignore advice"
  on advice for update to authenticated
  using ((owns_tree(tree_id) and has_plan('essential'))
         or (owns_zone(zone_id) and has_plan('connected')))
  with check ((owns_tree(tree_id) and has_plan('essential'))
              or (owns_zone(zone_id) and has_plan('connected')));


-- ---------- 8) ALERTS: regional = everyone, tree = essential, zone = connected ----------
-- (Policy "Everyone logged in sees regional alerts" is unchanged.)
drop policy if exists "Farmers see alerts for their orchards" on alerts;
create policy "Farmers see alerts for their orchards"
  on alerts for select to authenticated
  using ((type = 'tree' and owns_tree(tree_id) and has_plan('essential'))
         or (type = 'zone' and (owns_zone(zone_id) or owns_sensor(sensor_id)) and has_plan('connected')));


commit;
