-- =========================================================
-- LOOZ — Migration 014: the DATABASE keeps the demo admin on demo data
--
-- Until now, the "Connexion démo" account (the demo admin, e-mail
-- @looz-demo.invalid) saw only demo data in the dashboard because the
-- BACKEND filtered the lists. With its login token, the Supabase API could
-- still read every row. Now the database rules (RLS) themselves give it
-- demo data only:
--   1. Helpers: admin_sees_all() (a real admin), demo_person_ids() (the
--      demo accounts + the fake people of the community), demo_orchard_ids(),
--      demo_node_ids().
--   2. Every "Admins see ..." rule: a real admin sees everything (as
--      before); the demo admin sees only the rows of demo accounts / demo
--      orchards / demo boxes, its OWN lines of the action log, its demo
--      regional alerts, and the posts, answers and photos of demo accounts.
--      Old tables the dashboard does not use (sensors, alerts, answers,
--      tree photos, alert confirmations): nothing for the demo admin.
--   3. A demo regional alert (written by the demo admin) is shown ONLY to
--      demo accounts: real farmers never see a test of the jury demo.
--   4. admin_overview() (the numbers of "Vue d'ensemble"): the demo admin
--      gets numbers of demo data only (they match its lists).
--      admin_auth_users(), regional_alert_seen_count(): demo only too.
--   5. Last check.
-- Real admins and the app see exactly what they saw before.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 013. Safe to run again.
-- ⚠ If you ever run 012 or 013 again, run THIS file again afterwards: they
--   recreate the old "Admins see ..." rules.
-- =========================================================


-- ---------- 1) Helpers ----------
-- A real admin (not the demo admin): sees everything.
create or replace function public.admin_sees_all() returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() and not public.is_demo_admin();
$$;

-- The demo accounts (demo_account) and the fake people of the community (is_demo).
create or replace function public.demo_person_ids() returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(id), '{}') from profiles where is_demo or demo_account;
$$;

-- The demo orchards (marked is_demo, or of a demo account).
create or replace function public.demo_orchard_ids() returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(o.id), '{}') from orchards o
  where o.is_demo or o.farmer_id = any (public.demo_person_ids());
$$;

-- The boxes of the demo orchards.
create or replace function public.demo_node_ids() returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(n.id), '{}') from nodes n join zones z on z.id = n.zone_id
  where z.orchard_id = any (public.demo_orchard_ids());
$$;

revoke all on function public.admin_sees_all() from public, anon;
revoke all on function public.demo_person_ids() from public, anon;
revoke all on function public.demo_orchard_ids() from public, anon;
revoke all on function public.demo_node_ids() from public, anon;
grant execute on function public.admin_sees_all(), public.demo_person_ids(), public.demo_orchard_ids(),
  public.demo_node_ids() to authenticated, service_role;


-- ---------- 2) The rules: a real admin sees all, the demo admin demo rows ----------
-- "(select f())": computed once per query, not once per row.

drop policy if exists "Admins see all profiles" on profiles;
create policy "Admins see all profiles" on profiles for select to authenticated
  using ((select public.admin_sees_all()) or ((select public.is_demo_admin()) and (is_demo or demo_account)));

drop policy if exists "Admins see all subscriptions" on subscriptions;
create policy "Admins see all subscriptions" on subscriptions for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and user_id = any ((select public.demo_person_ids())::uuid[])));

drop policy if exists "Admins see all payments" on payments;
create policy "Admins see all payments" on payments for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and user_id = any ((select public.demo_person_ids())::uuid[])));

drop policy if exists "Admins see all installation visits" on kit_requests;
create policy "Admins see all installation visits" on kit_requests for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and user_id = any ((select public.demo_person_ids())::uuid[])));

drop policy if exists "Admins see all orchards" on orchards;
create policy "Admins see all orchards" on orchards for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and id = any ((select public.demo_orchard_ids())::uuid[])));

drop policy if exists "Admins see all zones" on zones;
create policy "Admins see all zones" on zones for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and orchard_id = any ((select public.demo_orchard_ids())::uuid[])));

drop policy if exists "Admins see all trees" on trees;
create policy "Admins see all trees" on trees for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and orchard_id = any ((select public.demo_orchard_ids())::uuid[])));

drop policy if exists "Admins see all nodes" on nodes;
create policy "Admins see all nodes" on nodes for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and id = any ((select public.demo_node_ids())::uuid[])));

drop policy if exists "Admins see the gateways" on gateways;
create policy "Admins see the gateways" on gateways for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and orchard_id = any ((select public.demo_orchard_ids())::uuid[])));

drop policy if exists "Admins see all latest readings" on node_latest;
create policy "Admins see all latest readings" on node_latest for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and node_id = any ((select public.demo_node_ids())::uuid[])));

drop policy if exists "Admins see all readings" on node_readings;
create policy "Admins see all readings" on node_readings for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and node_id = any ((select public.demo_node_ids())::uuid[])));

drop policy if exists "Admins see all alert events" on node_alert_events;
create policy "Admins see all alert events" on node_alert_events for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and node_id = any ((select public.demo_node_ids())::uuid[])));

drop policy if exists "Admins see all sensor problems" on node_fault_days;
create policy "Admins see all sensor problems" on node_fault_days for select to authenticated
  using ((select public.admin_sees_all())
         or ((select public.is_demo_admin()) and node_id = any ((select public.demo_node_ids())::uuid[])));

-- Old tables (not used by the dashboard): real admins only.
drop policy if exists "Admins see all sensors" on sensors;
create policy "Admins see all sensors" on sensors for select to authenticated using ((select public.admin_sees_all()));
drop policy if exists "Admins see all alerts" on alerts;
create policy "Admins see all alerts" on alerts for select to authenticated using ((select public.admin_sees_all()));
drop policy if exists "Admins see all answers" on answers;
create policy "Admins see all answers" on answers for select to authenticated using ((select public.admin_sees_all()));
drop policy if exists "Admins see all photos" on tree_photos;
create policy "Admins see all photos" on tree_photos for select to authenticated using ((select public.admin_sees_all()));
drop policy if exists "Admins see all confirmations" on alert_confirmations;
create policy "Admins see all confirmations" on alert_confirmations for select to authenticated
  using ((select public.admin_sees_all()));

-- The action log: the demo admin reads ITS OWN lines (no real admin name).
drop policy if exists "Admins read the action log" on admin_actions;
create policy "Admins read the action log" on admin_actions for select to authenticated
  using ((select public.admin_sees_all()) or ((select public.is_demo_admin()) and is_demo));

-- Community: users as before; the demo admin reads the posts and answers of
-- demo accounts (hidden ones too), and their reports.
drop policy if exists "Everyone logged in reads visible posts" on posts;
create policy "Everyone logged in reads visible posts" on posts for select to authenticated
  using (case when (select public.is_demo_admin()) then author_id = any ((select public.demo_person_ids())::uuid[])
              else hidden = false or author_id = auth.uid() or (select public.is_admin()) end);

drop policy if exists "Everyone logged in reads comments" on comments;
create policy "Everyone logged in reads comments" on comments for select to authenticated
  using ((case when (select public.is_demo_admin()) then author_id = any ((select public.demo_person_ids())::uuid[])
               else hidden = false or author_id = auth.uid() or (select public.is_admin()) end)
         and exists (select 1 from posts where posts.id = comments.post_id));

drop policy if exists "Users see their own reports" on content_reports;
create policy "Users see their own reports" on content_reports for select to authenticated
  using (reporter_id = auth.uid() or (select public.admin_sees_all())
         or ((select public.is_demo_admin())
             and (exists (select 1 from posts p where p.id = content_reports.post_id
                          and p.author_id = any ((select public.demo_person_ids())::uuid[]))
                  or exists (select 1 from comments c where c.id = content_reports.comment_id
                             and c.author_id = any ((select public.demo_person_ids())::uuid[])))));

-- Regional alerts: a demo alert reaches demo accounts only.
drop policy if exists "Users read the active alerts of their governorate" on regional_alerts;
create policy "Users read the active alerts of their governorate" on regional_alerts for select to authenticated
  using (case when (select public.is_admin()) then not (select public.is_demo_admin()) or is_demo
              else public.regional_alert_is_active(regional_alerts)
                   and (select public.my_governorate()) = any (governorates)
                   and (not is_demo or (select public.is_demo_person(auth.uid()))) end);

drop policy if exists "Users see their own Moi aussi" on regional_alert_reports;
create policy "Users see their own Moi aussi" on regional_alert_reports for select to authenticated
  using (user_id = auth.uid() or (select public.admin_sees_all())
         or ((select public.is_demo_admin())
             and exists (select 1 from regional_alerts a where a.id = alert_id and a.is_demo)));

-- Community photos (private bucket): the demo admin sees and deletes only
-- the photos of demo accounts (their folder = their id).
drop policy if exists "Community photos: see the photos of the posts" on storage.objects;
create policy "Community photos: see the photos of the posts"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'community'
    and ((storage.foldername(name))[1] = (select auth.uid()::text)
         or case when (select public.is_demo_admin())
                 then (storage.foldername(name))[1] = any ((select public.demo_person_ids())::text[])
                 else exists (select 1 from public.posts p
                              where p.photo = objects.name and p.photo not like 'demo:%' and not p.hidden)
                      or (select public.is_admin()) end)
  );

drop policy if exists "Community photos: delete your own" on storage.objects;
create policy "Community photos: delete your own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'community'
    and ((storage.foldername(name))[1] = (select auth.uid()::text)
         or (select public.admin_sees_all())
         or ((select public.is_demo_admin())
             and (storage.foldername(name))[1] = any ((select public.demo_person_ids())::text[])))
  );


-- ---------- 3) Reading functions of the dashboard ----------
-- The login facts: the demo admin gets the demo accounts only.
create or replace function public.admin_auth_users(p_ids uuid[] default null)
returns table (id uuid, email text, last_sign_in_at timestamptz, blocked boolean, demo_login boolean,
               created_at timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  perform public.require_admin();
  return query
  select u.id,
         case when p.role = 'admin' then u.email::text end,
         u.last_sign_in_at,
         coalesce(u.banned_until > now(), false),
         coalesce(u.raw_app_meta_data ->> 'demo_login' = 'true', false),
         u.created_at
  from auth.users u join public.profiles p on p.id = u.id
  where (p_ids is null or u.id = any (p_ids))
    and (not public.is_demo_admin() or p.is_demo or p.demo_account)
  limit 5000;
end;
$$;

-- "Moi aussi" count: for an alert the caller can see.
create or replace function public.regional_alert_seen_count(p_alert uuid) returns integer
language sql stable security definer set search_path = public as $$
  select case when exists (select 1 from regional_alerts a where a.id = p_alert
                           and ((public.is_admin() and (not public.is_demo_admin() or a.is_demo))
                                or (not public.is_admin()
                                    and public.regional_alert_is_active(a)
                                    and public.my_governorate() = any (a.governorates)
                                    and (not a.is_demo or public.is_demo_person(auth.uid())))))
              then (select count(*)::integer from regional_alert_reports where alert_id = p_alert) end;
$$;

-- "Vue d'ensemble": the demo admin counts demo data only (numbers = lists).
create or replace function public.admin_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  demo_only   boolean := public.is_demo_admin();
  people      uuid[] := public.demo_person_ids();
  demo_places uuid[] := public.demo_orchard_ids();
  month_start timestamptz := date_trunc('month', now() at time zone 'Africa/Tunis') at time zone 'Africa/Tunis';
  result      jsonb;
begin
  perform public.require_admin();
  with paid as (
    select user_id from subscriptions
    where coalesce(public.plan_rank(plan), 0) >= 1 and status = 'active' and (ends_at is null or ends_at > now())
  ), persons as (
    select * from profiles where not demo_only or id = any (people)
  ), places as (
    select * from orchards where not demo_only or id = any (demo_places)
  ), boxes as (
    select s.*, s.orchard_id = any (demo_places) as demo from iot_node_status s
    where not demo_only or s.orchard_id = any (demo_places)
  ), alerts as (
    select * from regional_alerts a where not demo_only or a.is_demo
  ), my_posts as (
    select * from posts where not demo_only or author_id = any (people)
  ), my_comments as (
    select * from comments where not demo_only or author_id = any (people)
  ), reports as (
    select r.*, coalesce(r.post_id, c.post_id) as of_post
    from content_reports r
    left join comments c on c.id = r.comment_id
    left join posts po on po.id = r.post_id
    where not demo_only or coalesce(po.author_id, c.author_id) = any (people)
  )
  select jsonb_build_object(
    'farmers', jsonb_build_object(
      'total', (select count(*) from persons where role = 'farmer'),
      'paid', (select count(*) from persons p join paid on paid.user_id = p.id where p.role = 'farmer'),
      'demo', (select count(*) from persons where role = 'farmer' and (is_demo or demo_account))),
    'experts', jsonb_build_object(
      'verified', (select count(*) from persons where role = 'expert' and verified),
      'waiting', (select count(*) from persons where role = 'expert' and not coalesce(verified, false))),
    'orchards', jsonb_build_object(
      'complete', (select count(*) from places where status = 'complete'),
      'draft', (select count(*) from places where status = 'draft')),
    'boxes', (select jsonb_build_object(
      'total', count(*),
      'waiting', count(*) filter (where status = 'waiting'),
      'installed', count(*) filter (where status = 'installed'),
      'online', count(*) filter (where status = 'online'),
      'offline', count(*) filter (where status = 'offline'),
      'sensor_problem', count(*) filter (where status = 'sensor_problem'),
      'critical', count(*) filter (where level = 'critical' and status in ('online', 'sensor_problem')))
      from boxes),
    'regional_alerts', jsonb_build_object(
      'active', (select count(*) from alerts a where public.regional_alert_is_active(a)),
      'danger', (select count(*) from alerts a where public.regional_alert_is_active(a) and severity = 'danger')),
    'community', jsonb_build_object(
      'posts_week', (select count(*) from my_posts where date > now() - interval '7 days'),
      'answers_week', (select count(*) from my_comments where created_at > now() - interval '7 days'),
      'hidden', (select count(*) from my_posts where hidden) + (select count(*) from my_comments where hidden),
      'reports_open', (select count(*) from reports where status = 'open')),
    'demo_payments_month', (select jsonb_build_object('count', count(*), 'millimes', coalesce(sum(amount_millimes), 0))
      from payments where status = 'paid_demo' and paid_at >= month_start
                          and (not demo_only or user_id = any (people))),
    'visits_open', (select count(*) from kit_requests
                    where status in ('new', 'contacted') and (not demo_only or user_id = any (people))),
    'todo', jsonb_build_object(
      'experts', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'governorate', zone,
                                                              'created_at', created_at) order by created_at)
        from (select * from persons where role = 'expert' and not coalesce(verified, false)
              order by created_at limit 10) x), '[]'::jsonb),
      'boxes_waiting', coalesce((select jsonb_agg(jsonb_build_object('node_id', b.node_id, 'device_code', b.device_code,
                                                                    'zone_letter', b.zone_letter, 'farmer_id', b.farmer_id,
                                                                    'farmer_name', p.name, 'refused_at', b.last_refused_at))
        from (select * from boxes where status = 'waiting' limit 10) b
        left join profiles p on p.id = b.farmer_id), '[]'::jsonb),
      'sensor_problems', coalesce((select jsonb_agg(jsonb_build_object('node_id', b.node_id, 'device_code', b.device_code,
                                                                      'zone_letter', b.zone_letter, 'farmer_id', b.farmer_id,
                                                                      'farmer_name', p.name, 'faults', b.faults, 'level', b.level))
        from (select * from boxes where status = 'sensor_problem' limit 10) b
        left join profiles p on p.id = b.farmer_id), '[]'::jsonb),
      'reports', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'post_id', r.of_post,
                                                              'comment_id', r.comment_id, 'reason', r.reason,
                                                              'created_at', r.created_at) order by r.created_at)
        from (select * from reports where status = 'open' order by created_at limit 10) r), '[]'::jsonb))
  ) into result;
  return result;
end;
$$;

revoke all on function public.admin_auth_users(uuid[]) from public, anon;
revoke all on function public.regional_alert_seen_count(uuid) from public, anon;
revoke all on function public.admin_overview() from public, anon;
grant execute on function public.admin_auth_users(uuid[]), public.regional_alert_seen_count(uuid),
  public.admin_overview() to authenticated, service_role;


-- ---------- 4) Last check: you should see  0 | 26 | true | 16 | false ----------
--   rules_not_demo_safe   0  = no rule left that lets the demo admin read everything
--   rules_updated        26  = the rules of this file
--   demo_admin_exists  true
--   demo_people          16  = 6 demo numbers + the demo admin + 9 fake people
--                              of the community (another number: tell Claude)
--   visitors_can_call  false
select
  (select count(*) from pg_policies
   where schemaname in ('public', 'storage')
     and (coalesce(qual, '') ~ 'is_admin\(\)' or coalesce(with_check, '') ~ 'is_admin\(\)')
     and coalesce(qual, '') !~ 'is_demo_admin|admin_sees_all')                                    as rules_not_demo_safe,
  (select count(*) from pg_policies
   where schemaname in ('public', 'storage')
     and coalesce(qual, '') ~ 'admin_sees_all|is_demo_admin')                                     as rules_updated,
  exists (select 1 from auth.users u join public.profiles p on p.id = u.id
          where u.email like '%@looz-demo.invalid' and p.role = 'admin')                         as demo_admin_exists,
  cardinality(public.demo_person_ids())                                                          as demo_people,
  has_function_privilege('anon', 'public.demo_person_ids()', 'execute')                          as visitors_can_call;
