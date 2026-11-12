-- =========================================================
-- LOOZ — Migration 013: the admin dashboard
--
-- What it does:
--   1. Admins READ everything, but CHANGE things only through the functions
--      of this file. Each function checks the rules and writes one line in
--      the ADMIN ACTION LOG (admin_actions: who, what, when, on what, why).
--      The old rules "Admins manage ..." (any change through the API) become
--      "Admins see ...". (The SQL Editor and the Table Editor are not
--      concerned: they never use these rules.)
--   2. Roles, the expert badge, packs: nobody changes them through the API,
--      admins included (profiles_protect_columns). A role stays SQL only.
--   3. REGIONAL ALERTS (new table regional_alerts): type, severity,
--      governorates, title / text / advice in Arabic AND French, start /
--      end. A logged-in user reads only the ACTIVE alerts of HIS
--      governorate. "Moi aussi" = regional_alert_reports.
--   4. Reports of community posts / answers (content_reports, for the
--      "report" button the app will get) and the moderation: hide, show
--      again, delete, always with a reason.
--   5. One checked function each for: the expert badge, blocking an account,
--      the price, the settings, the installation visits, the sensor boxes,
--      the gateways.
--   6. The DEMO ADMIN ("Connexion démo" of the dashboard): its switch
--      app_settings.demo_admin_login_enabled (OFF), demo accounts
--      (profiles.demo_account), its actions are marked "démo" in the log,
--      it acts only on demo things and never on settings, prices, gateways
--      or blocking.
--   7. Reading helpers: admin_overview() (the numbers of "Vue d'ensemble"),
--      iot_alert_log, orchard_summary, admin_auth_users().
--   8. Last check.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 012. Safe to run again (no begin/commit, each
-- statement can be run again).
-- ⚠ If you ever re-run looz_policies.sql or a migration 002 to 012, run
--   THIS file again afterwards: they recreate the old "Admins manage" rules.
-- ⚠ The sensor-box functions change: iot_unaccept_node now needs a reason:
--   select public.iot_unaccept_node(id, 'reason') from nodes where hardware_id = 'NODE-04';
-- =========================================================


-- ---------- 1) Settings, demo accounts, the demo admin ----------
alter table app_settings add column if not exists demo_admin_login_enabled boolean not null default false;
comment on column app_settings.demo_admin_login_enabled is
  'DEMO: true = the "Connexion démo" button of the admin dashboard logs in the demo admin. OFF by default.';

-- The dashboard asks it before showing "Connexion démo" (only a yes / no).
create or replace function public.demo_admin_login_enabled() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select s.demo_admin_login_enabled from app_settings s where s.id), false);
$$;

alter table profiles add column if not exists demo_account boolean not null default false;
comment on column profiles.demo_account is
  'A DEMO account that can log in (demo admin, demo farmers of the presentation). '
  'Not the same as is_demo (the fake people of the community, deleted by community_demo_delete.sql).';

-- The demo admin: an admin whose login e-mail ends with @looz-demo.invalid.
create or replace function public.is_demo_admin() returns boolean
language sql stable security definer set search_path = public, auth as $$
  select exists (select 1 from auth.users u join public.profiles p on p.id = u.id
                 where u.id = auth.uid() and p.role = 'admin' and u.email like '%@looz-demo.invalid');
$$;

-- A demo account (the demo admin may act only on these).
create or replace function public.is_demo_person(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = p_user and (is_demo or demo_account));
$$;

-- Through the API (the app, the dashboard), NOBODY changes these fields,
-- admins included. The functions of the database and the SQL Editor may.
create or replace function public.profiles_protect_columns() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user = 'authenticated' then
    if new.id             is distinct from old.id
    or new.phone          is distinct from old.phone
    or new.role           is distinct from old.role
    or new.verified       is distinct from old.verified
    or new.chosen_plan    is distinct from old.chosen_plan
    or new.payment_status is distinct from old.payment_status
    or new.plan_chosen_at is distinct from old.plan_chosen_at
    or new.created_at     is distinct from old.created_at
    or new.is_demo        is distinct from old.is_demo
    or new.demo_account   is distinct from old.demo_account then
      raise exception 'This field cannot be changed from the app' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;


-- ---------- 2) The admin action log ----------
create or replace function public.admin_action_codes() returns text[]
language sql immutable as $$
  select array['node_accept', 'node_unaccept', 'gateway_new_key', 'gateway_enable', 'gateway_disable',
               'visit_update', 'expert_verify', 'expert_unverify', 'user_block', 'user_unblock',
               'post_hide', 'post_unhide', 'post_delete', 'comment_hide', 'comment_unhide', 'comment_delete',
               'report_dismiss', 'alert_create', 'alert_update', 'alert_end', 'price_change', 'setting_change'];
$$;

create table if not exists admin_actions (
  id           bigint generated always as identity primary key,
  admin_id     uuid references profiles(id) on delete set null,
  admin_name   text not null default '',
  action       text not null check (action = any (public.admin_action_codes())),
  target_type  text not null check (target_type in ('node', 'gateway', 'visit', 'user', 'post', 'comment',
                                                    'report', 'regional_alert', 'price', 'setting')),
  target_id    text,
  target_label text,
  reason       text,
  details      jsonb not null default '{}'::jsonb,
  is_demo      boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists admin_actions_target_idx on admin_actions (target_type, target_id, created_at desc);
create index if not exists admin_actions_created_idx on admin_actions (created_at desc);
comment on table admin_actions is
  'Who did what, when, on what and why (written only by the functions of migration 013). Never changed.';

-- Writes one line (only from the functions below, never from the API).
create or replace function public.log_admin_action(p_action text, p_target_type text, p_target_id text,
                                                   p_target_label text, p_reason text, p_details jsonb)
returns bigint
language plpgsql security definer set search_path = public as $$
declare
  me     profiles;
  new_id bigint;
begin
  select * into me from profiles where id = auth.uid();
  insert into admin_actions (admin_id, admin_name, action, target_type, target_id, target_label, reason,
                             details, is_demo)
  values (me.id,
          case when me.id is null then 'SQL Editor'
               else coalesce(nullif(btrim(me.name), ''), 'Administrateur') end,
          p_action, p_target_type, p_target_id, left(p_target_label, 120), nullif(btrim(p_reason), ''),
          coalesce(p_details, '{}'::jsonb), public.is_demo_admin())
  returning id into new_id;
  return new_id;
end;
$$;

-- Every admin function starts here. p_demo_ok = false: not for the demo
-- admin. The SQL Editor (no logged-in user) may do everything.
create or replace function public.require_admin(p_demo_ok boolean default true) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    return;
  end if;
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if not p_demo_ok and public.is_demo_admin() then
    raise exception 'Not with the demo admin account' using errcode = '42501';
  end if;
end;
$$;

-- The demo admin acts only on demo things (demo person, demo orchard...).
create or replace function public.require_demo_target(p_is_demo boolean) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if public.is_demo_admin() and not coalesce(p_is_demo, false) then
    raise exception 'The demo admin acts only on demo accounts' using errcode = '42501';
  end if;
end;
$$;

-- A reason: 3 to 300 letters, no < >, no hidden characters.
create or replace function public.reason_ok(p text) returns boolean
language sql immutable as $$
  select p is not null and char_length(btrim(p)) >= 3 and public.community_text_ok(p, 300);
$$;


-- ---------- 3) Admins READ, functions WRITE ----------
drop policy if exists "Admins manage all profiles" on profiles;
drop policy if exists "Admins see all profiles" on profiles;
create policy "Admins see all profiles" on profiles for select to authenticated using (is_admin());

drop policy if exists "Admins manage subscriptions" on subscriptions;
drop policy if exists "Admins see all subscriptions" on subscriptions;
create policy "Admins see all subscriptions" on subscriptions for select to authenticated using (is_admin());

drop policy if exists "Admins manage nodes" on nodes;
drop policy if exists "Admins see all nodes" on nodes;
create policy "Admins see all nodes" on nodes for select to authenticated using (is_admin());

drop policy if exists "Admins manage gateways" on gateways;
drop policy if exists "Admins see the gateways" on gateways;
create policy "Admins see the gateways" on gateways for select to authenticated using (is_admin());

drop policy if exists "Admins manage kit requests" on kit_requests;
drop policy if exists "Admins see all installation visits" on kit_requests;
create policy "Admins see all installation visits" on kit_requests for select to authenticated using (is_admin());

drop policy if exists "Admins manage sensors" on sensors;
drop policy if exists "Admins see all sensors" on sensors;
create policy "Admins see all sensors" on sensors for select to authenticated using (is_admin());

drop policy if exists "Admins manage alerts" on alerts;
drop policy if exists "Admins see all alerts" on alerts;
create policy "Admins see all alerts" on alerts for select to authenticated using (is_admin());

drop policy if exists "Admins manage answers" on answers;
drop policy if exists "Admins see all answers" on answers;
create policy "Admins see all answers" on answers for select to authenticated using (is_admin());

-- (Admins already READ these through the rules of everyone / of 006, 009, 011.)
drop policy if exists "Admins change the settings" on app_settings;
drop policy if exists "Admins change the prices" on plan_prices;
drop policy if exists "Admins change orchards" on orchards;
drop policy if exists "Admins moderate posts" on posts;
drop policy if exists "Admins manage comments" on comments;

-- No logged-in user writes these tables directly (the functions do).
revoke insert, update, delete, truncate on nodes, gateways, kit_requests, subscriptions, plan_prices,
  app_settings, orchards from authenticated;


-- ---------- 4) Sensor boxes, gateways, installation visits ----------
-- "Accepter l'installation": the box may now send (p_device_code = the code
-- printed on the box, may be left empty if it has one). When every box of
-- the orchard is accepted, its installation visit is done.
drop function if exists public.iot_accept_node(uuid, text);
create or replace function public.iot_accept_node(p_node uuid, p_device_code text default null,
                                                  p_reason text default null)
returns nodes
language plpgsql security definer set search_path = public as $$
declare
  code   text := nullif(upper(btrim(p_device_code)), '');
  n      nodes;
  oid    uuid;
  demo   boolean;
  before timestamptz;
begin
  perform public.require_admin();
  if code is not null and code !~ '^[A-Z0-9][A-Z0-9_-]{1,39}$' then
    raise exception 'Device code: 2 to 40 capital letters, digits, - or _' using errcode = '22023';
  end if;
  if nullif(btrim(p_reason), '') is not null and not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  select z.orchard_id, o.is_demo, x.installed_at into oid, demo, before
  from nodes x join zones z on z.id = x.zone_id join orchards o on o.id = z.orchard_id
  where x.id = p_node and z.archived_at is null;
  if oid is null then
    raise exception 'Unknown box (or its zone was removed)' using errcode = 'P0002';
  end if;
  perform public.require_demo_target(demo);
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
  if n.hardware_id is null then
    raise exception 'Give the device code of the box' using errcode = '22023';
  end if;
  perform public.log_admin_action('node_accept', 'node', n.id::text, n.hardware_id, p_reason,
    jsonb_build_object('device_code', n.hardware_id, 'orchard_id', oid, 'already_accepted', before is not null));
  if not exists (select 1 from nodes x join zones z on z.id = x.zone_id
                 where z.orchard_id = oid and z.archived_at is null and x.installed_at is null) then
    update kit_requests set status = 'installed'
    where orchard_id = oid and status in ('new', 'contacted');
  end if;
  return n;
end;
$$;

-- "Retirer l'acceptation": the box is waiting again (its readings are refused).
drop function if exists public.iot_unaccept_node(uuid);
create or replace function public.iot_unaccept_node(p_node uuid, p_reason text)
returns nodes
language plpgsql security definer set search_path = public as $$
declare
  n    nodes;
  demo boolean;
begin
  perform public.require_admin();
  if not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  select o.is_demo into demo
  from nodes x join zones z on z.id = x.zone_id join orchards o on o.id = z.orchard_id where x.id = p_node;
  if not found then
    raise exception 'Unknown box' using errcode = 'P0002';
  end if;
  perform public.require_demo_target(demo);
  update nodes set installed_at = null, installed_by = null, status = 'offline'
  where id = p_node
  returning * into n;
  perform public.log_admin_action('node_unaccept', 'node', n.id::text, n.hardware_id, p_reason,
    jsonb_build_object('device_code', n.hardware_id));
  return n;
end;
$$;

-- A NEW secret key for a gateway (the old one stops at once). Shown only
-- here: paste it in the gateway's .env (LOOZ_GATEWAY_KEY). Never logged.
create or replace function public.iot_gateway_new_key(p_code text)
returns text
language plpgsql security definer set search_path = public as $$
declare
  new_key text := 'lgw_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  g       gateways;
begin
  perform public.require_admin(false);
  update gateways set key_hash = encode(sha256(convert_to(new_key, 'UTF8')), 'hex')
  where code = upper(btrim(p_code))
  returning * into g;
  if g.id is null then
    raise exception 'Unknown gateway %', p_code using errcode = 'P0002';
  end if;
  perform public.log_admin_action('gateway_new_key', 'gateway', g.code, g.code, null, '{}'::jsonb);
  return new_key;
end;
$$;

create or replace function public.admin_set_gateway_enabled(p_code text, p_enabled boolean, p_reason text)
returns gateways
language plpgsql security definer set search_path = public as $$
declare
  g gateways;
begin
  perform public.require_admin(false);
  if not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  update gateways set enabled = coalesce(p_enabled, enabled) where code = upper(btrim(p_code))
  returning * into g;
  if g.id is null then
    raise exception 'Unknown gateway %', p_code using errcode = 'P0002';
  end if;
  perform public.log_admin_action(case when g.enabled then 'gateway_enable' else 'gateway_disable' end,
    'gateway', g.code, g.code, p_reason, '{}'::jsonb);
  return g;
end;
$$;

-- An installation visit: "new" (to plan), "contacted", "cancelled", and a
-- note. "installed" is never set here: it comes by itself when every box of
-- the orchard is accepted.
create or replace function public.admin_update_visit(p_visit uuid, p_status text, p_note text)
returns kit_requests
language plpgsql security definer set search_path = public as $$
declare
  k     kit_requests;
  old_k kit_requests;
  demo  boolean;
begin
  perform public.require_admin();
  select * into old_k from kit_requests where id = p_visit;
  if old_k.id is null then
    raise exception 'Unknown visit' using errcode = 'P0002';
  end if;
  select o.is_demo into demo from orchards o where o.id = old_k.orchard_id;
  perform public.require_demo_target(coalesce(demo, public.is_demo_person(old_k.user_id)));
  if p_status is not null and p_status not in ('new', 'contacted', 'cancelled') then
    raise exception 'Status: new, contacted or cancelled ("installed" comes from the accepted boxes)'
      using errcode = '22023';
  end if;
  if p_status is not null and p_status <> old_k.status and old_k.status in ('installed', 'cancelled') then
    raise exception 'This visit is closed (%)', old_k.status using errcode = '22023';
  end if;
  if nullif(btrim(p_note), '') is not null and not public.community_text_ok(p_note, 500) then
    raise exception 'Note: up to 500 letters' using errcode = '22023';
  end if;
  update kit_requests set
    status = coalesce(p_status, status),
    admin_note = case when p_note is null then admin_note else nullif(btrim(p_note), '') end
  where id = p_visit
  returning * into k;
  perform public.log_admin_action('visit_update', 'visit', k.id::text, coalesce(k.phone, ''), null,
    jsonb_build_object('status_before', old_k.status, 'status', k.status,
                       'note_changed', k.admin_note is distinct from old_k.admin_note));
  return k;
end;
$$;


-- ---------- 5) Experts and accounts ----------
-- The "◆ خبير موثّق" badge of an expert (profiles.verified).
create or replace function public.admin_set_expert_verified(p_user uuid, p_verified boolean, p_reason text default null)
returns profiles
language plpgsql security definer set search_path = public as $$
declare
  p profiles;
begin
  perform public.require_admin();
  select * into p from profiles where id = p_user;
  if p.id is null then
    raise exception 'Unknown account' using errcode = 'P0002';
  end if;
  if p.role <> 'expert' then
    raise exception 'Only experts get the badge' using errcode = '22023';
  end if;
  perform public.require_demo_target(p.is_demo or p.demo_account);
  if not coalesce(p_verified, false) and not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  update profiles set verified = coalesce(p_verified, false) where id = p_user returning * into p;
  perform public.log_admin_action(case when p.verified then 'expert_verify' else 'expert_unverify' end,
    'user', p.id::text, p.name, p_reason, '{}'::jsonb);
  return p;
end;
$$;

-- Block an account (it cannot log in or renew its session: at most one more
-- hour in the app). Never an admin, never yourself. Unblock: p_blocked = false.
create or replace function public.admin_set_user_blocked(p_user uuid, p_blocked boolean, p_reason text)
returns timestamptz
language plpgsql security definer set search_path = public, auth as $$
declare
  p     profiles;
  until timestamptz;
begin
  perform public.require_admin(false);
  select * into p from profiles where id = p_user;
  if p.id is null then
    raise exception 'Unknown account' using errcode = 'P0002';
  end if;
  if p.role = 'admin' or p.id = auth.uid() then
    raise exception 'An admin account cannot be blocked here' using errcode = '42501';
  end if;
  if not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  until := case when coalesce(p_blocked, false) then '2999-12-31'::timestamptz end;
  update auth.users set banned_until = until where id = p_user;
  perform public.log_admin_action(case when until is null then 'user_unblock' else 'user_block' end,
    'user', p.id::text, p.name, p_reason, '{}'::jsonb);
  return until;
end;
$$;

-- What the dashboard shows about the login accounts (e-mail of admins only).
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
  where p_ids is null or u.id = any (p_ids)
  limit 5000;
end;
$$;


-- ---------- 6) Community: reports and moderation ----------
create table if not exists content_reports (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid references posts(id) on delete cascade,
  comment_id   uuid references comments(id) on delete cascade,
  reporter_id  uuid not null references profiles(id) on delete cascade,
  reason       text not null check (reason in ('spam', 'insult', 'wrong_advice', 'other')),
  note         text check (note is null or public.community_text_ok(note, 300)),
  status       text not null default 'open' check (status in ('open', 'dismissed', 'actioned')),
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz,
  resolved_by  uuid references profiles(id) on delete set null,
  constraint content_reports_one_target check ((post_id is null) <> (comment_id is null))
);
create unique index if not exists content_reports_once
  on content_reports (reporter_id, coalesce(post_id, comment_id));
create index if not exists content_reports_open_idx on content_reports (status, created_at desc);
comment on table content_reports is
  'A user reports a post or an answer (spam, insult, wrong advice, other). Written by report_content().';

-- The app ("Signaler", later): report a visible post or answer of someone
-- else. At most 10 reports a day.
create or replace function public.report_content(p_type text, p_id uuid, p_reason text, p_note text default null)
returns content_reports
language plpgsql security definer set search_path = public as $$
declare
  uid    uuid := auth.uid();
  author uuid;
  r      content_reports;
begin
  if uid is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if p_type = 'post' then
    select author_id into author from posts where id = p_id and not hidden;
  elsif p_type = 'comment' then
    select c.author_id into author from comments c join posts p on p.id = c.post_id
    where c.id = p_id and not c.hidden and not p.hidden;
  else
    raise exception 'Type: post or comment' using errcode = '22023';
  end if;
  if author is null then
    raise exception 'Nothing to report' using errcode = 'P0002';
  end if;
  if author = uid then
    raise exception 'You cannot report your own text' using errcode = '22023';
  end if;
  if coalesce(p_reason, '') not in ('spam', 'insult', 'wrong_advice', 'other') then
    raise exception 'Reason: spam, insult, wrong_advice or other' using errcode = '22023';
  end if;
  if nullif(btrim(p_note), '') is not null and not public.community_text_ok(p_note, 300) then
    raise exception 'Note: up to 300 letters' using errcode = '22023';
  end if;
  if (select count(*) from content_reports where reporter_id = uid and created_at > now() - interval '1 day') >= 10 then
    raise exception 'Too many reports today' using errcode = 'PT429';
  end if;
  insert into content_reports (post_id, comment_id, reporter_id, reason, note)
  values (case when p_type = 'post' then p_id end, case when p_type = 'comment' then p_id end,
          uid, p_reason, nullif(btrim(p_note), ''))
  on conflict do nothing
  returning * into r;
  if r.id is null then
    raise exception 'Already reported' using errcode = '23505';
  end if;
  return r;
end;
$$;

-- Hide, show again or delete a post or an answer, with a reason. The log
-- keeps a copy of the text. Delete a post: its photo (if any) is returned:
-- the dashboard then deletes the file with the Storage API.
create or replace function public.admin_moderate_content(p_type text, p_id uuid, p_action text, p_reason text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  author    profiles;
  author_id uuid;
  txt       text;
  photo     text;
  created   timestamptz;
  is_hidden boolean;
  answers   integer := 0;
  reports   integer;
  act       text := p_type || '_' || p_action;
begin
  perform public.require_admin();
  if p_type not in ('post', 'comment') or p_action not in ('hide', 'unhide', 'delete') then
    raise exception 'Type post / comment, action hide / unhide / delete' using errcode = '22023';
  end if;
  if not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  if p_type = 'post' then
    select p.text, p.photo, p.date, p.hidden, p.author_id into txt, photo, created, is_hidden, author_id
    from posts p where p.id = p_id;
    answers := (select count(*) from comments where post_id = p_id);
  else
    select c.text, null, c.created_at, c.hidden, c.author_id into txt, photo, created, is_hidden, author_id
    from comments c where c.id = p_id;
  end if;
  if txt is null then
    raise exception 'Unknown %', p_type using errcode = 'P0002';
  end if;
  select * into author from profiles where id = author_id;
  perform public.require_demo_target(author.is_demo or author.demo_account);
  reports := (select count(*) from content_reports
              where (post_id = p_id or comment_id = p_id) and status = 'open');

  if p_action = 'hide' or p_action = 'unhide' then
    if p_type = 'post' then
      update posts set hidden = (p_action = 'hide') where id = p_id;
    else
      update comments set hidden = (p_action = 'hide') where id = p_id;
    end if;
  end if;
  if p_action in ('hide', 'delete') then
    update content_reports set status = 'actioned', resolved_at = now(), resolved_by = auth.uid()
    where (post_id = p_id or comment_id = p_id) and status = 'open';
  end if;
  perform public.log_admin_action(act, p_type, p_id::text, left(txt, 60), p_reason,
    jsonb_build_object('author_id', author.id, 'author_name', author.name, 'text', left(txt, 300),
                       'photo', photo, 'created_at', created, 'was_hidden', is_hidden,
                       'answers', answers, 'open_reports', reports));
  if p_action = 'delete' then
    if p_type = 'post' then
      delete from posts where id = p_id;
    else
      delete from comments where id = p_id;
    end if;
  end if;
  return jsonb_build_object('photo', case when p_action = 'delete' and photo is not null
                                           and photo not like 'demo:%' then photo end);
end;
$$;

create or replace function public.admin_dismiss_report(p_report uuid, p_reason text)
returns content_reports
language plpgsql security definer set search_path = public as $$
declare
  r      content_reports;
  author uuid;
begin
  perform public.require_admin();
  if not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  select * into r from content_reports where id = p_report;
  if r.id is null then
    raise exception 'Unknown report' using errcode = 'P0002';
  end if;
  if r.status <> 'open' then
    raise exception 'This report is already closed' using errcode = '22023';
  end if;
  author := coalesce((select author_id from posts where id = r.post_id),
                     (select author_id from comments where id = r.comment_id));
  perform public.require_demo_target(public.is_demo_person(author));
  update content_reports set status = 'dismissed', resolved_at = now(), resolved_by = auth.uid()
  where id = p_report returning * into r;
  perform public.log_admin_action('report_dismiss', 'report', r.id::text, r.reason, p_reason,
    jsonb_build_object('post_id', r.post_id, 'comment_id', r.comment_id));
  return r;
end;
$$;


-- ---------- 7) Regional alerts ----------
create or replace function public.governorate_codes() returns text[]
language sql immutable as $$
  select array['tunis', 'ariana', 'ben_arous', 'manouba', 'nabeul', 'zaghouan', 'bizerte', 'beja',
               'jendouba', 'kef', 'siliana', 'sousse', 'monastir', 'mahdia', 'sfax', 'kairouan',
               'kasserine', 'sidi_bouzid', 'gabes', 'medenine', 'tataouine', 'gafsa', 'tozeur', 'kebili'];
$$;

create table if not exists regional_alerts (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null check (kind in ('frost', 'heat', 'drought', 'disease', 'pest', 'wind', 'rain')),
  severity     text not null check (severity in ('info', 'warning', 'danger')),
  governorates text[] not null
               check (cardinality(governorates) between 1 and 24 and governorates <@ public.governorate_codes()),
  title_ar     text not null,
  title_fr     text not null,
  body_ar      text not null,
  body_fr      text not null,
  advice_ar    text,
  advice_fr    text,
  starts_at    timestamptz not null default now(),
  ends_at      timestamptz,
  ended_at     timestamptz,
  ended_by     uuid references profiles(id) on delete set null,
  created_by   uuid references profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_by   uuid references profiles(id) on delete set null,
  updated_at   timestamptz not null default now(),
  is_demo      boolean not null default false,
  constraint regional_alerts_texts_check check (
    public.community_text_ok(title_ar, 80) and public.community_text_ok(title_fr, 80)
    and public.community_text_ok(body_ar, 600) and public.community_text_ok(body_fr, 600)
    and ((advice_ar is null and advice_fr is null)
         or (public.community_text_ok(advice_ar, 400) and public.community_text_ok(advice_fr, 400)))),
  constraint regional_alerts_dates_check check (ends_at is null or ends_at > starts_at)
);
create index if not exists regional_alerts_active_idx on regional_alerts (starts_at, ends_at) where ended_at is null;
comment on table regional_alerts is
  'Regional alerts written by admins (frost, heat, drought, disease, pest, wind, rain), in Arabic and French.';

-- The governorate of the logged-in user.
create or replace function public.my_governorate() returns text
language sql stable security definer set search_path = public as $$
  select zone from profiles where id = auth.uid();
$$;

-- Active = started, not past its end, not ended by an admin.
create or replace function public.regional_alert_is_active(a regional_alerts) returns boolean
language sql stable as $$
  select a.ended_at is null and a.starts_at <= now() and (a.ends_at is null or a.ends_at > now());
$$;

-- What is wrong with an alert (null = fine): clear messages for the dashboard.
create or replace function public.regional_alert_problem(a regional_alerts) returns text
language plpgsql immutable as $$
begin
  if a.kind is null or a.kind not in ('frost', 'heat', 'drought', 'disease', 'pest', 'wind', 'rain') then
    return 'kind: frost, heat, drought, disease, pest, wind or rain';
  end if;
  if a.severity is null or a.severity not in ('info', 'warning', 'danger') then
    return 'severity: info, warning or danger';
  end if;
  if a.governorates is null or cardinality(a.governorates) = 0 or not a.governorates <@ public.governorate_codes() then
    return 'governorates: one or more of the 24 codes';
  end if;
  if not public.community_text_ok(a.title_ar, 80) or a.title_ar !~ '[ء-ي]' then
    return 'title_ar: 1 to 80 letters, in Arabic';
  end if;
  if not public.community_text_ok(a.title_fr, 80) or a.title_fr !~ '[A-Za-z]' then
    return 'title_fr: 1 to 80 letters, in French';
  end if;
  if not public.community_text_ok(a.body_ar, 600) or a.body_ar !~ '[ء-ي]' then
    return 'body_ar: 1 to 600 letters, in Arabic';
  end if;
  if not public.community_text_ok(a.body_fr, 600) or a.body_fr !~ '[A-Za-z]' then
    return 'body_fr: 1 to 600 letters, in French';
  end if;
  if (a.advice_ar is null) <> (a.advice_fr is null) then
    return 'advice: in both languages, or none';
  end if;
  if a.advice_ar is not null and (not public.community_text_ok(a.advice_ar, 400) or a.advice_ar !~ '[ء-ي]') then
    return 'advice_ar: 1 to 400 letters, in Arabic';
  end if;
  if a.advice_fr is not null and (not public.community_text_ok(a.advice_fr, 400) or a.advice_fr !~ '[A-Za-z]') then
    return 'advice_fr: 1 to 400 letters, in French';
  end if;
  if a.starts_at is null then
    return 'starts_at: a date';
  end if;
  if a.ends_at is not null and a.ends_at <= a.starts_at then
    return 'ends_at: after starts_at';
  end if;
  return null;
end;
$$;

-- Create (no "id") or change (with "id") a regional alert. p:
--   {"id"?, "kind", "severity", "governorates": ["sfax", ...] or "all",
--    "title_ar", "title_fr", "body_ar", "body_fr", "advice_ar"?, "advice_fr"?,
--    "starts_at"? (default now), "ends_at"? (empty = until ended)}
create or replace function public.admin_save_regional_alert(p jsonb)
returns regional_alerts
language plpgsql security definer set search_path = public as $$
declare
  a       regional_alerts;
  old_a   regional_alerts;
  problem text;
  changed text[] := '{}';
  f       text;
begin
  perform public.require_admin();
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'An object expected' using errcode = '22023';
  end if;
  if p ? 'id' and jsonb_typeof(p -> 'id') <> 'null' then
    select * into old_a from regional_alerts where id = (p ->> 'id')::uuid;
    if old_a.id is null then
      raise exception 'Unknown alert' using errcode = 'P0002';
    end if;
    if old_a.ended_at is not null then
      raise exception 'This alert is ended' using errcode = '22023';
    end if;
    perform public.require_demo_target(old_a.is_demo);
    a := old_a;
  else
    a.starts_at := now();
  end if;
  if p ? 'kind' then a.kind := p ->> 'kind'; end if;
  if p ? 'severity' then a.severity := p ->> 'severity'; end if;
  if p ? 'governorates' then
    if p ->> 'governorates' = 'all' then
      a.governorates := public.governorate_codes();
    elsif jsonb_typeof(p -> 'governorates') = 'array' then
      a.governorates := array(select distinct g from jsonb_array_elements_text(p -> 'governorates') g order by 1);
    else
      a.governorates := null;
    end if;
  end if;
  foreach f in array array['title_ar', 'title_fr', 'body_ar', 'body_fr', 'advice_ar', 'advice_fr'] loop
    if p ? f then
      a := jsonb_populate_record(a, jsonb_build_object(f, nullif(btrim(p ->> f, E' \n\r'), '')));
    end if;
  end loop;
  if p ? 'starts_at' then
    a.starts_at := coalesce(public.iot_time(p ->> 'starts_at'), case when p ->> 'starts_at' is null then now() end);
  end if;
  if p ? 'ends_at' then
    a.ends_at := public.iot_time(p ->> 'ends_at');
    if a.ends_at is null and nullif(p ->> 'ends_at', '') is not null then
      raise exception 'ends_at: a date with its time zone' using errcode = '22023';
    end if;
  end if;
  problem := public.regional_alert_problem(a);
  if problem is not null then
    raise exception 'Wrong alert: %', problem using errcode = '22023';
  end if;

  if old_a.id is null then
    insert into regional_alerts (kind, severity, governorates, title_ar, title_fr, body_ar, body_fr,
                                 advice_ar, advice_fr, starts_at, ends_at, created_by, updated_by, is_demo)
    values (a.kind, a.severity, a.governorates, a.title_ar, a.title_fr, a.body_ar, a.body_fr,
            a.advice_ar, a.advice_fr, a.starts_at, a.ends_at, auth.uid(), auth.uid(), public.is_demo_admin())
    returning * into a;
    perform public.log_admin_action('alert_create', 'regional_alert', a.id::text, a.title_fr, null,
      jsonb_build_object('kind', a.kind, 'severity', a.severity, 'governorates', a.governorates));
  else
    foreach f in array array['kind', 'severity', 'governorates', 'title_ar', 'title_fr', 'body_ar', 'body_fr',
                             'advice_ar', 'advice_fr', 'starts_at', 'ends_at'] loop
      if (to_jsonb(a) -> f) is distinct from (to_jsonb(old_a) -> f) then
        changed := changed || f;
      end if;
    end loop;
    update regional_alerts set
      kind = a.kind, severity = a.severity, governorates = a.governorates,
      title_ar = a.title_ar, title_fr = a.title_fr, body_ar = a.body_ar, body_fr = a.body_fr,
      advice_ar = a.advice_ar, advice_fr = a.advice_fr, starts_at = a.starts_at, ends_at = a.ends_at,
      updated_by = auth.uid(), updated_at = now()
    where id = a.id
    returning * into a;
    perform public.log_admin_action('alert_update', 'regional_alert', a.id::text, a.title_fr, null,
      jsonb_build_object('changed', changed));
  end if;
  return a;
end;
$$;

-- End an alert now (it disappears from the app at once).
create or replace function public.admin_end_regional_alert(p_id uuid, p_reason text)
returns regional_alerts
language plpgsql security definer set search_path = public as $$
declare
  a regional_alerts;
begin
  perform public.require_admin();
  if not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  select * into a from regional_alerts where id = p_id;
  if a.id is null then
    raise exception 'Unknown alert' using errcode = 'P0002';
  end if;
  if a.ended_at is not null then
    raise exception 'This alert is already ended' using errcode = '22023';
  end if;
  perform public.require_demo_target(a.is_demo);
  update regional_alerts set ended_at = now(), ended_by = auth.uid(), updated_at = now()
  where id = p_id returning * into a;
  perform public.log_admin_action('alert_end', 'regional_alert', a.id::text, a.title_fr, p_reason, '{}'::jsonb);
  return a;
end;
$$;

-- "Moi aussi": the users who saw it too (on an alert they can see).
create table if not exists regional_alert_reports (
  alert_id   uuid not null references regional_alerts(id) on delete cascade,
  user_id    uuid not null default auth.uid() references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (alert_id, user_id)
);

-- How many said "Moi aussi" (only for an alert the caller can see).
create or replace function public.regional_alert_seen_count(p_alert uuid) returns integer
language sql stable security definer set search_path = public as $$
  select case when exists (select 1 from regional_alerts a where a.id = p_alert
                           and (public.is_admin()
                                or (public.regional_alert_is_active(a)
                                    and public.my_governorate() = any (a.governorates))))
              then (select count(*)::integer from regional_alert_reports where alert_id = p_alert) end;
$$;


-- ---------- 8) Price and settings ----------
-- The price of ONE node for period_days days (8000 millimes = 8 DT).
create or replace function public.admin_set_price(p_price_millimes integer, p_reason text)
returns plan_prices
language plpgsql security definer set search_path = public as $$
declare
  before integer := (select price_millimes from plan_prices where plan = 'paid');
  pr     plan_prices;
begin
  perform public.require_admin(false);
  if p_price_millimes is null or p_price_millimes not between 1000 and 1000000 then
    raise exception 'Price: 1 to 1000 DT (1000 to 1000000 millimes)' using errcode = '22023';
  end if;
  if not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  update plan_prices set price_millimes = p_price_millimes where plan = 'paid' returning * into pr;
  perform public.log_admin_action('price_change', 'price', 'paid', 'Prix par boîtier', p_reason,
    jsonb_build_object('before', before, 'after', p_price_millimes));
  return pr;
end;
$$;

-- One setting of app_settings (only these). p_value as text:
--   demo_payments_enabled, demo_login_enabled, iot_ingest_enabled,
--   demo_admin_login_enabled: 'true' / 'false'
--   hectares_per_node: a number 0.1 to 1000, or '' (= only the zones drawn)
--   iot_history_days: 1 to 3650
create or replace function public.admin_set_setting(p_name text, p_value text, p_reason text)
returns app_settings
language plpgsql security definer set search_path = public as $$
declare
  before jsonb;
  s      app_settings;
  v      text := btrim(coalesce(p_value, ''));
begin
  perform public.require_admin(false);
  if not public.reason_ok(p_reason) then
    raise exception 'Reason: 3 to 300 letters' using errcode = '22023';
  end if;
  select to_jsonb(x) -> p_name into before from app_settings x where x.id;
  if p_name in ('demo_payments_enabled', 'demo_login_enabled', 'iot_ingest_enabled', 'demo_admin_login_enabled') then
    if v not in ('true', 'false') then
      raise exception '%: true or false', p_name using errcode = '22023';
    end if;
    execute format('update app_settings set %I = $1, updated_at = now() where id', p_name) using v::boolean;
  elsif p_name = 'hectares_per_node' then
    if v <> '' and (v !~ '^[0-9]+(\.[0-9]{1,2})?$' or v::numeric not between 0.10 and 1000) then
      raise exception 'hectares_per_node: 0.10 to 1000, or empty' using errcode = '22023';
    end if;
    update app_settings set hectares_per_node = nullif(v, '')::numeric, updated_at = now() where id;
  elsif p_name = 'iot_history_days' then
    if v !~ '^[0-9]{1,4}$' or v::integer not between 1 and 3650 then
      raise exception 'iot_history_days: 1 to 3650' using errcode = '22023';
    end if;
    update app_settings set iot_history_days = v::integer, updated_at = now() where id;
  else
    raise exception 'Unknown setting %', p_name using errcode = '22023';
  end if;
  select * into s from app_settings where id;
  perform public.log_admin_action('setting_change', 'setting', p_name, p_name, p_reason,
    jsonb_build_object('before', before, 'after', to_jsonb(s) -> p_name));
  return s;
end;
$$;


-- ---------- 9) Reading helpers (the rules of the reader apply) ----------
-- The sensor alerts of every orchard (admins), or of your own boxes.
create or replace view public.iot_alert_log with (security_invoker = true) as
select e.id,
       e.measured_at,
       e.received_at,
       e.level,
       e.previous_level,
       e.reasons,
       e.cause,
       e.confidence,
       e.water_stress,
       e.heat_stress,
       e.soil_moisture_pct,
       e.air_temp_c,
       e.faults,
       e.node_id,
       n.hardware_id as device_code,
       z.letter      as zone_letter,
       z.orchard_id,
       o.farmer_id,
       o.is_demo     as demo_orchard,
       p.name        as farmer_name,
       p.zone        as governorate
from node_alert_events e
join nodes n on n.id = e.node_id
join zones z on z.id = n.zone_id
join orchards o on o.id = z.orchard_id
left join profiles p on p.id = o.farmer_id;

-- One line per orchard: zones, trees, boxes.
create or replace view public.orchard_summary with (security_invoker = true) as
select o.id,
       o.farmer_id,
       o.status,
       o.area,
       o.is_demo,
       o.draw_mode,
       o.created_at,
       o.completed_at,
       (select count(*) from zones z where z.orchard_id = o.id and z.archived_at is null)          as zones,
       (select count(*) from trees t where t.orchard_id = o.id and t.archived_at is null)          as trees,
       (select count(*) from nodes n join zones z on z.id = n.zone_id
        where z.orchard_id = o.id and z.archived_at is null)                                      as boxes,
       (select count(*) from nodes n join zones z on z.id = n.zone_id
        where z.orchard_id = o.id and z.archived_at is null and n.installed_at is not null)       as boxes_accepted
from orchards o;

-- The numbers and the "À faire" lists of "Vue d'ensemble" (one call).
-- The demo admin gets the same numbers, but lists with demo accounts only.
create or replace function public.admin_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  demo_only boolean := public.is_demo_admin();
  month_start timestamptz := date_trunc('month', now() at time zone 'Africa/Tunis') at time zone 'Africa/Tunis';
  result jsonb;
begin
  perform public.require_admin();
  with paid as (
    select user_id from subscriptions
    where coalesce(public.plan_rank(plan), 0) >= 1 and status = 'active' and (ends_at is null or ends_at > now())
  ), boxes as (
    select s.*, o.is_demo as demo from iot_node_status s join orchards o on o.id = s.orchard_id
  )
  select jsonb_build_object(
    'farmers', jsonb_build_object(
      'total', (select count(*) from profiles where role = 'farmer'),
      'paid', (select count(*) from profiles p join paid on paid.user_id = p.id where p.role = 'farmer'),
      'demo', (select count(*) from profiles where role = 'farmer' and (is_demo or demo_account))),
    'experts', jsonb_build_object(
      'verified', (select count(*) from profiles where role = 'expert' and verified),
      'waiting', (select count(*) from profiles where role = 'expert' and not coalesce(verified, false))),
    'orchards', jsonb_build_object(
      'complete', (select count(*) from orchards where status = 'complete'),
      'draft', (select count(*) from orchards where status = 'draft')),
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
      'active', (select count(*) from regional_alerts a where public.regional_alert_is_active(a)),
      'danger', (select count(*) from regional_alerts a where public.regional_alert_is_active(a) and severity = 'danger')),
    'community', jsonb_build_object(
      'posts_week', (select count(*) from posts where date > now() - interval '7 days'),
      'answers_week', (select count(*) from comments where created_at > now() - interval '7 days'),
      'hidden', (select count(*) from posts where hidden) + (select count(*) from comments where hidden),
      'reports_open', (select count(*) from content_reports where status = 'open')),
    'demo_payments_month', (select jsonb_build_object('count', count(*), 'millimes', coalesce(sum(amount_millimes), 0))
      from payments where status = 'paid_demo' and paid_at >= month_start),
    'visits_open', (select count(*) from kit_requests where status in ('new', 'contacted')),
    'todo', jsonb_build_object(
      'experts', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'governorate', zone,
                                                              'created_at', created_at) order by created_at)
        from (select * from profiles where role = 'expert' and not coalesce(verified, false)
              and (not demo_only or is_demo or demo_account) order by created_at limit 10) x), '[]'::jsonb),
      'boxes_waiting', coalesce((select jsonb_agg(jsonb_build_object('node_id', b.node_id, 'device_code', b.device_code,
                                                                    'zone_letter', b.zone_letter, 'farmer_id', b.farmer_id,
                                                                    'farmer_name', p.name, 'refused_at', b.last_refused_at))
        from (select * from boxes where status = 'waiting' and (not demo_only or demo) limit 10) b
        left join profiles p on p.id = b.farmer_id), '[]'::jsonb),
      'sensor_problems', coalesce((select jsonb_agg(jsonb_build_object('node_id', b.node_id, 'device_code', b.device_code,
                                                                      'zone_letter', b.zone_letter, 'farmer_id', b.farmer_id,
                                                                      'farmer_name', p.name, 'faults', b.faults, 'level', b.level))
        from (select * from boxes where status = 'sensor_problem' and (not demo_only or demo) limit 10) b
        left join profiles p on p.id = b.farmer_id), '[]'::jsonb),
      'reports', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'post_id', coalesce(r.post_id, c.post_id),
                                                              'comment_id', r.comment_id, 'reason', r.reason,
                                                              'created_at', r.created_at) order by r.created_at)
        from (select * from content_reports where status = 'open' order by created_at limit 10) r
        left join comments c on c.id = r.comment_id
        left join posts po on po.id = coalesce(r.post_id, c.post_id)
        where not demo_only or public.is_demo_person(po.author_id)), '[]'::jsonb))
  ) into result;
  return result;
end;
$$;


-- ---------- 10) The rules (RLS) of the new tables and the rights ----------
alter table admin_actions          enable row level security;
alter table content_reports        enable row level security;
alter table regional_alerts        enable row level security;
alter table regional_alert_reports enable row level security;

drop policy if exists "Admins read the action log" on admin_actions;
create policy "Admins read the action log" on admin_actions for select to authenticated using (is_admin());

drop policy if exists "Users see their own reports" on content_reports;
create policy "Users see their own reports" on content_reports for select to authenticated
  using (reporter_id = auth.uid() or is_admin());

drop policy if exists "Users read the active alerts of their governorate" on regional_alerts;
create policy "Users read the active alerts of their governorate" on regional_alerts for select to authenticated
  using (is_admin() or (public.regional_alert_is_active(regional_alerts) and my_governorate() = any (governorates)));

drop policy if exists "Users see their own Moi aussi" on regional_alert_reports;
create policy "Users see their own Moi aussi" on regional_alert_reports for select to authenticated
  using (user_id = auth.uid() or is_admin());
drop policy if exists "Users say Moi aussi on an alert they see" on regional_alert_reports;
create policy "Users say Moi aussi on an alert they see" on regional_alert_reports for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from regional_alerts a where a.id = alert_id));
drop policy if exists "Users take back their Moi aussi" on regional_alert_reports;
create policy "Users take back their Moi aussi" on regional_alert_reports for delete to authenticated
  using (user_id = auth.uid());

revoke all on admin_actions, content_reports, regional_alerts, regional_alert_reports from anon, authenticated;
grant select on admin_actions, content_reports, regional_alerts to authenticated;
grant select, insert, delete on regional_alert_reports to authenticated;
grant all on admin_actions, content_reports, regional_alerts, regional_alert_reports to service_role;
revoke all on public.iot_alert_log, public.orchard_summary from anon, authenticated;
grant select on public.iot_alert_log, public.orchard_summary to authenticated, service_role;

-- Functions: the admin ones to logged-in users (they check is_admin), the
-- internal ones to nobody, the demo switch to everyone (a yes / no only).
revoke all on function public.log_admin_action(text, text, text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.require_admin(boolean)                   from public, anon;
revoke all on function public.require_demo_target(boolean)             from public, anon;
revoke all on function public.iot_accept_node(uuid, text, text)        from public, anon;
revoke all on function public.iot_unaccept_node(uuid, text)            from public, anon;
revoke all on function public.iot_gateway_new_key(text)                from public, anon;
revoke all on function public.admin_set_gateway_enabled(text, boolean, text) from public, anon;
revoke all on function public.admin_update_visit(uuid, text, text)     from public, anon;
revoke all on function public.admin_set_expert_verified(uuid, boolean, text) from public, anon;
revoke all on function public.admin_set_user_blocked(uuid, boolean, text) from public, anon;
revoke all on function public.admin_auth_users(uuid[])                 from public, anon;
revoke all on function public.report_content(text, uuid, text, text)   from public, anon;
revoke all on function public.admin_moderate_content(text, uuid, text, text) from public, anon;
revoke all on function public.admin_dismiss_report(uuid, text)         from public, anon;
revoke all on function public.admin_save_regional_alert(jsonb)         from public, anon;
revoke all on function public.admin_end_regional_alert(uuid, text)     from public, anon;
revoke all on function public.regional_alert_seen_count(uuid)          from public, anon;
revoke all on function public.admin_set_price(integer, text)           from public, anon;
revoke all on function public.admin_set_setting(text, text, text)      from public, anon;
revoke all on function public.admin_overview()                         from public, anon;
grant execute on function public.iot_accept_node(uuid, text, text), public.iot_unaccept_node(uuid, text),
  public.iot_gateway_new_key(text), public.admin_set_gateway_enabled(text, boolean, text),
  public.admin_update_visit(uuid, text, text), public.admin_set_expert_verified(uuid, boolean, text),
  public.admin_set_user_blocked(uuid, boolean, text), public.admin_auth_users(uuid[]),
  public.report_content(text, uuid, text, text), public.admin_moderate_content(text, uuid, text, text),
  public.admin_dismiss_report(uuid, text), public.admin_save_regional_alert(jsonb),
  public.admin_end_regional_alert(uuid, text), public.regional_alert_seen_count(uuid),
  public.admin_set_price(integer, text), public.admin_set_setting(text, text, text),
  public.admin_overview(), public.require_admin(boolean), public.require_demo_target(boolean)
  to authenticated, service_role;
grant execute on function public.demo_admin_login_enabled() to anon, authenticated, service_role;


-- ---------- 11) Last check: you should see  0 | true | false | true | false | 0 | 0 ----------
select
  (select count(*) from pg_policies where schemaname = 'public' and policyname like 'Admins%'
     and cmd <> 'SELECT')                                                                       as admin_write_rules_left,
  (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace
     and relname in ('admin_actions', 'content_reports', 'regional_alerts', 'regional_alert_reports')) as rules_on,
  (select demo_admin_login_enabled from app_settings where id)                                 as demo_admin_login_on,
  has_function_privilege('anon', 'public.demo_admin_login_enabled()', 'execute')               as dashboard_can_ask_demo_switch,
  has_function_privilege('anon', 'public.admin_overview()', 'execute')                         as visitors_can_call_admin_functions,
  (select count(*) from admin_actions where action not in (select unnest(public.admin_action_codes()))) as bad_log_lines,
  (select count(*) from regional_alerts a where public.regional_alert_problem(a) is not null)  as bad_alerts;
