-- =========================================================
-- LOOZ — Migration 015: the "التنبيهات / Alertes" tab of the app
--
-- The regional alerts (written by admins in the dashboard, migration 013)
-- now reach the app. What this file adds:
--   1. regional_alert_reads: for each user and alert, WHEN he opened it
--      (the unread badge of the tab: an alert changed by an admin after
--      that counts as new again) and when he tapped "تمّ / Fait".
--      Users read only their own rows. Nobody writes it by hand: only the
--      functions below.
--   2. regional_alert_for_me(alert): the alert is for the logged-in user:
--      active, of his governorate, and a demo alert only for a demo account.
--      (The same rule as the reading rule of regional_alerts, migration 014.)
--   3. The functions of the app:
--        my_regional_alerts()               the list of the tab, with the
--                                           "Moi aussi" count, mine, new, done
--        regional_alert_mark(id, state)     'read' (opened), 'done', 'undone'
--        regional_alert_me_too(id, on)      "أنا أيضًا / Moi aussi" on / off
--                                           -> the new count
--   4. The dashboard: regional_alert_reach(ids) = how many users opened each
--      alert and how many tapped "Fait" (admins; the demo admin: demo alerts).
--   5. Last check.
-- The "Signaler / إبلاغ" button of the community uses report_content() of
-- migration 013 (one report per user and text, 10 a day, never your own):
-- nothing new is needed for it.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 014. Safe to run again.
-- =========================================================


-- ---------- 1) Opened / done, per user and alert ----------
create table if not exists regional_alert_reads (
  alert_id  uuid not null references regional_alerts(id) on delete cascade,
  user_id   uuid not null references profiles(id) on delete cascade,
  read_at   timestamptz not null default now(),
  done_at   timestamptz,
  primary key (alert_id, user_id)
);
create index if not exists regional_alert_reads_user_idx on regional_alert_reads (user_id);
comment on table regional_alert_reads is
  'When a user opened a regional alert (read_at) and tapped "Fait" (done_at). Written only by regional_alert_mark / regional_alert_me_too.';


-- ---------- 2) Is this alert for the logged-in user? ----------
create or replace function public.regional_alert_for_me(a regional_alerts) returns boolean
language sql stable set search_path = public as $$
  select auth.uid() is not null
     and public.regional_alert_is_active(a)
     and coalesce(public.my_governorate() = any (a.governorates), false)
     and (not a.is_demo or public.is_demo_person(auth.uid()));
$$;


-- ---------- 3) The functions of the app ----------
-- The list of the tab: not done first, then the most serious, then the newest.
create or replace function public.my_regional_alerts()
returns table (id uuid, kind text, severity text, title_ar text, title_fr text, body_ar text, body_fr text,
               advice_ar text, advice_fr text, starts_at timestamptz, ends_at timestamptz,
               updated_at timestamptz, seen_count integer, me_too boolean, is_new boolean, done boolean)
language sql stable security definer set search_path = public as $$
  select a.id, a.kind, a.severity, a.title_ar, a.title_fr, a.body_ar, a.body_fr,
         a.advice_ar, a.advice_fr, a.starts_at, a.ends_at, a.updated_at,
         (select count(*)::integer from regional_alert_reports r where r.alert_id = a.id),
         exists (select 1 from regional_alert_reports r where r.alert_id = a.id and r.user_id = auth.uid()),
         rd.read_at is null or rd.read_at < a.updated_at,
         rd.done_at is not null
  from regional_alerts a
  left join regional_alert_reads rd on rd.alert_id = a.id and rd.user_id = auth.uid()
  where public.regional_alert_for_me(a)
  order by rd.done_at is not null,
           case a.severity when 'danger' then 3 when 'warning' then 2 else 1 end desc,
           a.starts_at desc
  limit 50;
$$;

-- The user opened the alert ('read'), tapped "تمّ / Fait" ('done') or took it back ('undone').
create or replace function public.regional_alert_mark(p_alert uuid, p_state text)
returns regional_alert_reads
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  a   regional_alerts;
  r   regional_alert_reads;
begin
  if uid is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if coalesce(p_state, '') not in ('read', 'done', 'undone') then
    raise exception 'State: read, done or undone' using errcode = '22023';
  end if;
  select * into a from regional_alerts where id = p_alert;
  if a.id is null or not public.regional_alert_for_me(a) then
    raise exception 'This alert is not for you (ended, other governorate)' using errcode = 'P0002';
  end if;
  insert into regional_alert_reads as x (alert_id, user_id, read_at, done_at)
  values (p_alert, uid, now(), case when p_state = 'done' then now() end)
  on conflict (alert_id, user_id) do update set
    read_at = now(),
    done_at = case p_state when 'done' then coalesce(x.done_at, now())
                           when 'undone' then null
                           else x.done_at end
  returning * into r;
  return r;
end;
$$;

-- "أنا أيضًا / Moi aussi": on (true) or taken back (false). Returns the new count.
create or replace function public.regional_alert_me_too(p_alert uuid, p_on boolean)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  a   regional_alerts;
begin
  if uid is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if p_on is null then
    raise exception 'On: true or false' using errcode = '22023';
  end if;
  select * into a from regional_alerts where id = p_alert;
  if a.id is null or not public.regional_alert_for_me(a) then
    raise exception 'This alert is not for you (ended, other governorate)' using errcode = 'P0002';
  end if;
  if p_on then
    insert into regional_alert_reports (alert_id, user_id) values (p_alert, uid) on conflict do nothing;
  else
    delete from regional_alert_reports where alert_id = p_alert and user_id = uid;
  end if;
  -- Tapping the button = the alert was opened.
  insert into regional_alert_reads as x (alert_id, user_id) values (p_alert, uid)
  on conflict (alert_id, user_id) do update set read_at = now();
  return (select count(*)::integer from regional_alert_reports where alert_id = p_alert);
end;
$$;


-- ---------- 4) The dashboard: how many opened / did it ----------
create or replace function public.regional_alert_reach(p_ids uuid[])
returns table (alert uuid, opened integer, done integer)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin();
  return query
  select a.id,
         (select count(*)::integer from regional_alert_reads r where r.alert_id = a.id),
         (select count(*)::integer from regional_alert_reads r where r.alert_id = a.id and r.done_at is not null)
  from regional_alerts a
  where a.id = any (p_ids) and (not public.is_demo_admin() or a.is_demo);
end;
$$;


-- ---------- The rules (RLS) and rights ----------
alter table regional_alert_reads enable row level security;
drop policy if exists "Users see their own alert reads" on regional_alert_reads;
create policy "Users see their own alert reads" on regional_alert_reads for select to authenticated
  using (user_id = auth.uid());

revoke all on regional_alert_reads from anon, authenticated;
grant select on regional_alert_reads to authenticated;
grant all on regional_alert_reads to service_role;

revoke all on function public.regional_alert_for_me(regional_alerts) from public, anon;
revoke all on function public.my_regional_alerts()                    from public, anon;
revoke all on function public.regional_alert_mark(uuid, text)         from public, anon;
revoke all on function public.regional_alert_me_too(uuid, boolean)    from public, anon;
revoke all on function public.regional_alert_reach(uuid[])            from public, anon;
grant execute on function public.regional_alert_for_me(regional_alerts), public.my_regional_alerts(),
  public.regional_alert_mark(uuid, text), public.regional_alert_me_too(uuid, boolean),
  public.regional_alert_reach(uuid[])
  to authenticated, service_role;


-- ---------- 5) Last check: you should see  true | false | false | true | true ----------
--   rules_on              true  = the table has its rules (RLS)
--   app_can_write_reads   false = the app writes only through the functions
--   visitors_can_call     false = not logged in: nothing
--   app_can_read_alerts   true  = the app's list function
--   app_can_report        true  = "Signaler" (report_content of 013)
select
  (select relrowsecurity from pg_class where oid = 'public.regional_alert_reads'::regclass)          as rules_on,
  has_table_privilege('authenticated', 'public.regional_alert_reads', 'insert')
    or has_table_privilege('authenticated', 'public.regional_alert_reads', 'update')               as app_can_write_reads,
  has_function_privilege('anon', 'public.my_regional_alerts()', 'execute')                         as visitors_can_call,
  has_function_privilege('authenticated', 'public.my_regional_alerts()', 'execute')                as app_can_read_alerts,
  has_function_privilege('authenticated', 'public.report_content(text, uuid, text, text)', 'execute') as app_can_report;
