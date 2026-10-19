-- =========================================================
-- LOOZ — Security rules (RLS) — FULL VERSION
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Safe to run again: it removes old versions before recreating.
-- =========================================================


-- ---------- 0) Turn on RLS for every table (the "locks") ----------
alter table profiles            enable row level security;
alter table posts               enable row level security;
alter table answers             enable row level security;
alter table subscriptions       enable row level security;
alter table orchard_plans       enable row level security;
alter table orchards            enable row level security;
alter table trees               enable row level security;
alter table sensors             enable row level security;
alter table advice              enable row level security;
alter table field_actions       enable row level security;
alter table alerts              enable row level security;
alter table alert_confirmations enable row level security;


-- ---------- 1) Tree positions for the 3D view ----------
alter table trees add column if not exists pos_x real;
alter table trees add column if not exists pos_z real;


-- ---------- 2) Helper functions (small reusable checks) ----------

-- Role of the logged-in user ('farmer', 'expert' or 'admin')
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid();
$$;

-- Is the logged-in user verified? (used for experts)
create or replace function public.my_verified() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(verified, false) from profiles where id = auth.uid();
$$;

-- Is the logged-in user an admin?
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- Is the logged-in user a VERIFIED expert?
create or replace function public.is_verified_expert() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles
                 where id = auth.uid() and role = 'expert' and verified = true);
$$;

-- Does the logged-in user own this orchard?
create or replace function public.owns_orchard(o_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from orchards where id = o_id and farmer_id = auth.uid());
$$;

-- Does the logged-in user own this tree (through its orchard)?
create or replace function public.owns_tree(t_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from trees t join orchards o on o.id = t.orchard_id
    where t.id = t_id and o.farmer_id = auth.uid()
  );
$$;


-- ---------- 3) Auto-create a profile when someone signs up ----------
-- New users are 'farmer' by default, or 'expert' (NOT verified) if they chose it.
-- Admins are NEVER created from the app: set role = 'admin' by hand in Table Editor.
-- Experts are verified by hand: set verified = true in Table Editor.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, role, name, phone)
  values (
    new.id,
    case when new.raw_user_meta_data->>'role' = 'expert' then 'expert' else 'farmer' end,
    coalesce(new.raw_user_meta_data->>'name', 'New user'),
    new.phone
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------- 4) PROFILES ----------
drop policy if exists "Logged-in users can see profiles" on profiles;
create policy "Logged-in users can see profiles"
  on profiles for select to authenticated using (true);

-- A user edits his own profile, but cannot change his role or verified badge
drop policy if exists "Users edit their own profile" on profiles;
create policy "Users edit their own profile"
  on profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = my_role() and verified = my_verified());

drop policy if exists "Admins manage all profiles" on profiles;
create policy "Admins manage all profiles"
  on profiles for all to authenticated using (is_admin()) with check (is_admin());


-- ---------- 5) POSTS ----------
drop policy if exists "Everyone logged in reads visible posts" on posts;
create policy "Everyone logged in reads visible posts"
  on posts for select to authenticated
  using (hidden = false or author_id = auth.uid() or is_admin());

drop policy if exists "Users write their own posts" on posts;
create policy "Users write their own posts"
  on posts for insert to authenticated
  with check (author_id = auth.uid() and hidden = false);

-- FIX: a post hidden by an admin can no longer be edited or un-hidden by its author
drop policy if exists "Users edit their own posts" on posts;
drop policy if exists "Users edit their own visible posts" on posts;
create policy "Users edit their own visible posts"
  on posts for update to authenticated
  using (author_id = auth.uid() and hidden = false)
  with check (author_id = auth.uid() and hidden = false);

drop policy if exists "Users delete their own posts" on posts;
create policy "Users delete their own posts"
  on posts for delete to authenticated using (author_id = auth.uid());

drop policy if exists "Admins moderate posts" on posts;
create policy "Admins moderate posts"
  on posts for all to authenticated using (is_admin()) with check (is_admin());


-- ---------- 6) ANSWERS ----------
drop policy if exists "Everyone logged in reads answers" on answers;
create policy "Everyone logged in reads answers"
  on answers for select to authenticated using (true);

-- FIX: only VERIFIED experts can answer
drop policy if exists "Only experts write answers" on answers;
drop policy if exists "Only verified experts write answers" on answers;
create policy "Only verified experts write answers"
  on answers for insert to authenticated
  with check (expert_id = auth.uid() and is_verified_expert());

drop policy if exists "Experts edit their own answers" on answers;
create policy "Experts edit their own answers"
  on answers for update to authenticated
  using (expert_id = auth.uid()) with check (expert_id = auth.uid());

drop policy if exists "Admins manage answers" on answers;
create policy "Admins manage answers"
  on answers for all to authenticated using (is_admin()) with check (is_admin());


-- ---------- 7) SUBSCRIPTIONS ----------
drop policy if exists "Farmers see their own subscription" on subscriptions;
create policy "Farmers see their own subscription"
  on subscriptions for select to authenticated using (farmer_id = auth.uid());

drop policy if exists "Farmers create their own subscription" on subscriptions;
create policy "Farmers create their own subscription"
  on subscriptions for insert to authenticated with check (farmer_id = auth.uid());

drop policy if exists "Admins manage subscriptions" on subscriptions;
create policy "Admins manage subscriptions"
  on subscriptions for all to authenticated using (is_admin()) with check (is_admin());


-- ---------- 8) ORCHARD PLANS ----------
drop policy if exists "Farmers manage their own plans" on orchard_plans;
create policy "Farmers manage their own plans"
  on orchard_plans for all to authenticated
  using (farmer_id = auth.uid()) with check (farmer_id = auth.uid());


-- ---------- 9) ORCHARDS ----------
drop policy if exists "Farmers manage their own orchards" on orchards;
create policy "Farmers manage their own orchards"
  on orchards for all to authenticated
  using (farmer_id = auth.uid()) with check (farmer_id = auth.uid());

drop policy if exists "Admins see all orchards" on orchards;
create policy "Admins see all orchards"
  on orchards for select to authenticated using (is_admin());


-- ---------- 10) TREES ----------
drop policy if exists "Farmers manage trees in their orchards" on trees;
create policy "Farmers manage trees in their orchards"
  on trees for all to authenticated
  using (owns_orchard(orchard_id)) with check (owns_orchard(orchard_id));

drop policy if exists "Admins see all trees" on trees;
create policy "Admins see all trees"
  on trees for select to authenticated using (is_admin());


-- ---------- 11) SENSORS ----------
drop policy if exists "Farmers see sensors on their trees" on sensors;
create policy "Farmers see sensors on their trees"
  on sensors for select to authenticated using (owns_tree(tree_id));

drop policy if exists "Admins manage sensors" on sensors;
create policy "Admins manage sensors"
  on sensors for all to authenticated using (is_admin()) with check (is_admin());


-- ---------- 12) ADVICE (created by the AI service, which bypasses RLS) ----------
drop policy if exists "Farmers see advice for their trees" on advice;
create policy "Farmers see advice for their trees"
  on advice for select to authenticated using (owns_tree(tree_id));

drop policy if exists "Farmers accept or ignore advice" on advice;
create policy "Farmers accept or ignore advice"
  on advice for update to authenticated
  using (owns_tree(tree_id)) with check (owns_tree(tree_id));


-- ---------- 13) FIELD ACTIONS ----------
drop policy if exists "Farmers manage actions in their orchards" on field_actions;
create policy "Farmers manage actions in their orchards"
  on field_actions for all to authenticated
  using (owns_orchard(orchard_id)) with check (owns_orchard(orchard_id));


-- ---------- 14) ALERTS ----------
drop policy if exists "Everyone logged in sees regional alerts" on alerts;
create policy "Everyone logged in sees regional alerts"
  on alerts for select to authenticated using (type = 'regional');

drop policy if exists "Farmers see alerts from their own sensors" on alerts;
create policy "Farmers see alerts from their own sensors"
  on alerts for select to authenticated
  using (
    type = 'tree' and exists (
      select 1 from sensors s where s.id = sensor_id and owns_tree(s.tree_id)
    )
  );

drop policy if exists "Admins manage alerts" on alerts;
create policy "Admins manage alerts"
  on alerts for all to authenticated using (is_admin()) with check (is_admin());


-- ---------- 15) ALERT CONFIRMATIONS ----------
drop policy if exists "Farmers confirm alerts for themselves" on alert_confirmations;
create policy "Farmers confirm alerts for themselves"
  on alert_confirmations for insert to authenticated with check (farmer_id = auth.uid());

drop policy if exists "Farmers see their own confirmations" on alert_confirmations;
create policy "Farmers see their own confirmations"
  on alert_confirmations for select to authenticated using (farmer_id = auth.uid());

drop policy if exists "Admins see all confirmations" on alert_confirmations;
create policy "Admins see all confirmations"
  on alert_confirmations for select to authenticated using (is_admin());