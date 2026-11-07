-- =========================================================
-- LOOZ — Migration 010: DEMO LOGIN (any number, any 6-digit code)
--
-- What it does:
--   1. app_settings.demo_login_enabled (true at first): while it is true,
--      ANY Tunisian number (+216 + 8 digits) and ANY 6-digit code log in,
--      for sign in and sign up. No SMS is sent. Only admins change it
--      (Table Editor > app_settings > false = the normal SMS code, at once).
--      !! Turn it OFF before a real launch: while it is on, anyone who
--      types a phone number can open that account.
--   2. demo_login_check(): what the Edge Function "demo-auth" needs to
--      know about a number (is the demo on? which account? an admin?
--      how many demo accounts in the last hour?). Only the Edge Function
--      can call it (service_role): not the app, not a visitor.
--   3. last check
--
-- The login itself is done by the Edge Function "demo-auth"
-- (supabase/functions/demo-auth/index.ts): it creates the account if
-- needed (phone confirmed, no SMS) and gives the app a normal session.
-- The service_role key stays in the Edge Function, never in the app.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 009. Safe to run again (no begin/commit, each
-- statement can be run again).
-- =========================================================


-- ---------- 1) The switch (one more column of app_settings) ----------
-- Same rules as the other settings (009): logged-in users read it, only an
-- admin changes it, nobody adds or deletes the row.
alter table app_settings
  add column if not exists demo_login_enabled boolean not null default true;
comment on column app_settings.demo_login_enabled is
  'DEMO: true = any +216 number and any 6-digit code log in, no SMS. TURN IT OFF BEFORE A REAL LAUNCH.';


-- ---------- 2) What the Edge Function needs to know about a number ----------
-- p_phone: '+21622123456' (spaces and '+' are ignored; Supabase Auth keeps
-- the number without '+'). One row:
--   enabled                 the switch (false if the settings row is missing)
--   user_id                 the account of this number (null = no account)
--   is_admin                true = an admin: never opened by the demo login
--   new_accounts_last_hour  accounts made by the demo login in the last hour
create or replace function public.demo_login_check(p_phone text)
returns table (
  enabled                boolean,
  user_id                uuid,
  is_admin               boolean,
  new_accounts_last_hour integer
)
language sql stable security definer set search_path = public, auth as $$
  select
    coalesce((select s.demo_login_enabled from public.app_settings s where s.id), false),
    u.id,
    coalesce(p.role = 'admin', false),
    (select count(*)::integer
       from auth.users n
      where n.created_at > now() - interval '1 hour'
        and n.raw_app_meta_data->>'demo_login' = 'true')
  from (select regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g') as digits) asked
  left join auth.users u
         on u.phone = asked.digits and asked.digits <> '' and u.deleted_at is null
  left join public.profiles p on p.id = u.id
  limit 1;
$$;
comment on function public.demo_login_check(text) is
  'DEMO LOGIN: called only by the Edge Function demo-auth (service_role).';

-- Only the Edge Function (service_role). Supabase gives every new function
-- to anon and authenticated by default: taken back here.
revoke all on function public.demo_login_check(text) from public, anon, authenticated;
grant execute on function public.demo_login_check(text) to service_role;


-- ---------- 3) Last check: you should see  true | false | false | true ----------
select
  (select demo_login_enabled from app_settings where id)                              as demo_login_on,
  has_function_privilege('anon', 'public.demo_login_check(text)', 'execute')          as visitors_can_call,
  has_function_privilege('authenticated', 'public.demo_login_check(text)', 'execute') as users_can_call,
  has_function_privilege('service_role', 'public.demo_login_check(text)', 'execute')  as edge_function_can_call;
